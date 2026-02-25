using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Application as App;
using Toybox.Activity as Act;
using Toybox.ActivityMonitor as Actmon;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Greg;
using Toybox.WatchUi as WatchUi;



class TestView extends Ui.WatchFace {

    var geo_small        = null;
    var geo_number_small = null;
    var custom           = null;
    var calibri_numbers  = null;
    var mirrored         = false;
    var showNotifications = true;
    var logo             = null;
    var _isSleeping      = false;

    // ── Fase 4: Buffer estático y soporte onPartialUpdate ───────────────────────
    // _bgBuffer almacena la capa visual que cambia solo cada minuto: fecha,
    // bateria, altitud, pasos, linea, arcos, logo, telefono, notificaciones.
    // La hora y la FC se dibujan encima del buffer en cada onUpdate o
    // en onPartialUpdate (llamado cada segundo en relojes AMOLED).
    var _bgBuffer     = null;   // BufferedBitmap (SDK 3.x+; null si no soportado)
    var _bufferDirty  = true;   // true → redibujar buffer en el proximo onUpdate
    var _lastMinute   = -1;     // minuto en el que se dibujó el buffer por ultima vez
    var _displayWidth  = 0;
    var _displayHeight = 0;
    // Altitud de referencia para el cálculo por defecto de pisos
    var _startAltitude = null;
    // Area del clip para onPartialUpdate (zona izquierda donde estan hora/min)
    var _timeClipX = 0;
    var _timeClipY = 0;
    var _timeClipW = 0;
    var _timeClipH = 0;

    function initialize() {
        Ui.WatchFace.initialize();
    }

    function onLayout(dc) {
        geo_small        = Ui.loadResource(Rez.Fonts.geo_small);
        geo_number_small = Ui.loadResource(Rez.Fonts.geo_number_small);
        custom           = Ui.loadResource(Rez.Fonts.custom);
        calibri_numbers  = Ui.loadResource(Rez.Fonts.calibri_numbers);
        logo             = Ui.loadResource(Rez.Drawables.triboost);
        _displayWidth    = dc.getWidth();
        _displayHeight   = dc.getHeight();
        // Crear el BufferedBitmap si el dispositivo lo soporta (SDK 3.x+)
        if (Graphics has :createBufferedBitmap) {
            var ref = Graphics.createBufferedBitmap(
                {:width => _displayWidth, :height => _displayHeight}
            );
            _bgBuffer = ref.get();
        }
        _bufferDirty = true;
    }

    // ── _drawStaticLayer ─────────────────────────────────────────────────────
    // Dibuja en targetDc los elementos que cambian como mucho cada minuto:
    // fecha, bateria, altitud, pasos, conexion, notificaciones, linea, arcos, logo.
    // Se usa tanto para el BufferedBitmap como para el dc real en dispositivos sin buffer.
    function _drawStaticLayer(targetDc, layout, data) {
        // var xRight intentionally unused in this layer (kept in layout for compatibility)
        var yDate     = layout[:yDate];
        var yAlt      = layout[:yAlt];
        var yStepsArc = (_displayHeight * 0.25).toNumber();
        var yPhone    = layout[:yPhone];
        var yNotif    = layout[:yNotif];
        var arcRadius = layout[:arcRadius];
        var arcCY     = layout[:arcCY];
        var arcBatX   = layout[:arcBatX];

        var dateString = data[:dateString];
        var batPct     = data[:batPct];
        var batColor   = data[:batColor];
        var altStr     = data[:altStr];
        var floor      = data[:floor];
        var steps      = data[:steps];
        var stepsGoal  = data[:stepsGoal];
        var stepsColor = data[:stepsColor];

        targetDc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        targetDc.clear();

        // --- Bezel / battery rim: draw progress arcs showing battery level ---
        var cx = (_displayWidth / 2).toNumber();
        var cy = (_displayHeight / 2).toNumber();
        var outerRadius = (((_displayWidth < _displayHeight) ? _displayWidth : _displayHeight) / 2 - 2).toNumber();
        var innerRadius = (outerRadius - 6).toNumber();
        // Use the same progress-drawing helper as other arcs so the filled portion
        // represents `batPct` and the remainder is shown in DK_GRAY.
        // Draw bezel as a partial/full arc with a bottom gap centered at 270º
        // Compute start angle so: gapMid = startAngle - (bezelSweep / 2)
        // For bezelSweep=340, startAngle = gapMid + 170 => gapMid 270 -> startAngle 80
        var bezelStart = 80;
        var bezelSweep = 340;
        _drawBezelProgress(targetDc, cx, cy, outerRadius, data[:batPct], 100, data[:batColor], bezelStart, bezelSweep);
        _drawBezelProgress(targetDc, cx, cy, innerRadius, data[:batPct], 100, data[:batColor], bezelStart, bezelSweep);
        // Draw battery percentage inside the bezel gap (centered in the empty arc)
        // Place gap midpoint angle at 90º (top of the watch)
        var gapMid = 90.0;
        var rad = (gapMid * Math.PI / 180.0).toFloat();
        var textRadius = (innerRadius - 8).toNumber();
        var pctX = (cx + Math.cos(rad) * textRadius).toNumber();
        var pctY = (cy - Math.sin(rad) * textRadius).toNumber();
        // Nudge percentage slightly upwards so it sits above the bezel gap
        var pctYOffset = 16; // pixels (moved 8px more)
        pctY = (pctY - pctYOffset).toNumber();
        targetDc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        targetDc.drawText(pctX, pctY, geo_small, (data[:batPct].toString() + "%"), Gfx.TEXT_JUSTIFY_CENTER);
        // --------------------------------------------------------------------

        // Fecha
        targetDc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        targetDc.drawText(_displayWidth / 2, yDate, geo_small, dateString, Gfx.TEXT_JUSTIFY_CENTER);

        // Arco pasos (derecha, junto a la hora)
        // Queremos que el BORDE IZQUIERDO del arco esté en 55% del ancho.
        var leftArcX = (_displayWidth * 0.55).toNumber();
        var xStepsArc = (leftArcX + arcRadius).toNumber();
        // Draw steps arc using user's steps and goal; background gray, fill uses stepsColor
        _drawProgressArcOnDc(targetDc, xStepsArc, yStepsArc, arcRadius, steps, stepsGoal, stepsColor);
        targetDc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        targetDc.drawText(xStepsArc, yStepsArc - (arcRadius * 0.35).toNumber(), geo_small,
            steps.toString(), Gfx.TEXT_JUSTIFY_CENTER);
        // Gaps independientes para ALT y NOT (estimación proporcional + mínimo)
        var labelGapAlt = (_displayWidth * 0.02).toNumber();
        var gapAltPx = labelGapAlt;
        // Altitud gap mínimo (ajustado a 6px)
        if (gapAltPx < 6) { gapAltPx = 6; }

        var labelGapNot = (_displayWidth * 0.02).toNumber();
        var gapNotPx = labelGapNot;
        // Notificaciones gap mínimo (ajustado a 10px)
        if (gapNotPx < 10) { gapNotPx = 10; }

        // Altitud: etiqueta "ALT" en gris y valor numérico en blanco
        var altLabel = "ALT";
        // Estimación conservadora del ancho por carácter (mejor que 0.018 para evitar solapamientos)
        var altLabelWidth = (altLabel.length() * (_displayWidth * 0.032)).toNumber();
        targetDc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        targetDc.drawText(leftArcX, yAlt, geo_small, altLabel, Gfx.TEXT_JUSTIFY_LEFT);
        targetDc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        targetDc.drawText(leftArcX + altLabelWidth + gapAltPx, yAlt, geo_small, altStr, Gfx.TEXT_JUSTIFY_LEFT);

        // Mostrar FLOOR (pisos) justo debajo de ALT usando la misma referencia X
        if (floor == null) { floor = 0; }
        var floorLabel = "FLR";
        var floorY = (_displayHeight * 0.58).toNumber();
        var floorLabelWidth = (floorLabel.length() * (_displayWidth * 0.032)).toNumber();
        targetDc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        targetDc.drawText(leftArcX, floorY, geo_small, floorLabel, Gfx.TEXT_JUSTIFY_LEFT);
        targetDc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        targetDc.drawText(leftArcX + floorLabelWidth + gapAltPx, floorY, geo_small, floor.format("%.0f"), Gfx.TEXT_JUSTIFY_LEFT);

        // Conexion telefono
        if (Sys.getDeviceSettings().phoneConnected) {
            targetDc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
            targetDc.drawText(leftArcX, yPhone, geo_small, "Conectado", Gfx.TEXT_JUSTIFY_LEFT);
        } else {
            targetDc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
            targetDc.drawText(leftArcX, yPhone, geo_small, "Desconectado", Gfx.TEXT_JUSTIFY_LEFT);
        }

        // Notificaciones: etiqueta "NOT" en gris y valor en blanco (formato similar a ALT)
        if (showNotifications && (Sys.DeviceSettings has :notificationCount)) {
            var notif = Sys.getDeviceSettings().notificationCount;
            var nLabel = notif.toString();
            var notLabel = "NOT";
            // Estimación conservadora del ancho por carácter (evita solapamientos)
            var notLabelWidth = (notLabel.length() * (_displayWidth * 0.032)).toNumber();
            targetDc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
            targetDc.drawText(leftArcX, yNotif, geo_small, notLabel, Gfx.TEXT_JUSTIFY_LEFT);
            targetDc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
            targetDc.drawText(leftArcX + notLabelWidth + gapNotPx, yNotif, geo_small, nLabel, Gfx.TEXT_JUSTIFY_LEFT);
        }

        // Left battery arc removed (now represented in the bezel)

        // Logo: center horizontally, keep Y at 70% of display height
        if (logo != null) {
            var logoW = logo.getWidth().toNumber();
            var logoH = logo.getHeight().toNumber();
            // Some SDKs don't support drawBitmap(x,y,w,h,bitmap). Use compatible call.
            var logoX = ((_displayWidth / 2) - (logoW / 2)).toNumber();
            var logoY = (_displayHeight * 0.70).toNumber();
            targetDc.drawBitmap(logoX, logoY, logo);
        }
    }

    // ── _drawDynamicLayer ─────────────────────────────────────────────────────
    // Dibuja sobre el dc real los elementos que cambian cada segundo: hora y FC.
    // Se llama siempre despues de blitear el buffer (o tras _drawStaticLayer en el
    // fallback sin buffer), de modo que sobrescribe el placeholder de FC del buffer.
    function _drawDynamicLayer(dc, xLeft, yHour, yMin, xRight, yHr, strhour, strmin) {
        // Hora (amarillo) y minutos (gris oscuro) - ambos calculados
            dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
            dc.drawText(_getXMin(_displayWidth), _getYHour(_displayHeight), calibri_numbers, strhour, Gfx.TEXT_JUSTIFY_CENTER);
            dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
            dc.drawText(_getXMin(_displayWidth), _getYMin(_displayHeight), calibri_numbers, strmin, Gfx.TEXT_JUSTIFY_CENTER);

        // Frecuencia cardiaca: visualización comentada por petición
        /*
        var hrInfo = Act.getActivityInfo().currentHeartRate;
        var arcRadius = (_displayHeight * 0.11).toNumber();
        var leftArcX = (_displayWidth * 0.55).toNumber();
        var cy = yHr; // Usar porcentaje homogeneizado (45% alto)
        if (hrInfo != null && hrInfo > 0) {
            dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
            dc.drawText(leftArcX, cy, geo_small, hrInfo.toString() + " bpm", Gfx.TEXT_JUSTIFY_LEFT);
        } else {
            dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
            dc.drawText(leftArcX, cy, geo_small, "-- bpm", Gfx.TEXT_JUSTIFY_LEFT);
        }
        */
    }

    // ── onUpdate ─────────────────────────────────────────────────────────────
    // Llamado por el sistema una vez por minuto (o al forzar WatchUi.requestUpdate).
    // En relojes AMOLED, onPartialUpdate se encarga de los segundos intermedios.
    function onUpdate(dc) {
        var displayHeight = (_displayHeight > 0) ? _displayHeight : dc.getHeight();
        var displayWidth  = (_displayWidth  > 0) ? _displayWidth  : dc.getWidth();

        // ── Modo sleep: pantalla minimalista ──────────────────────────────────
        if (_isSleeping) {
            dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
            dc.clear();
            var sleepClock = Sys.getClockTime();
            var sleepHour  = sleepClock.hour;
            if (!Sys.getDeviceSettings().is24Hour) {
                sleepHour = sleepHour % 12;
                if (sleepHour == 0) { sleepHour = 12; }
            }
            var sleepStr = sleepHour.format("%02d") + ":" + sleepClock.min.format("%02d");
            dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
            dc.drawText(displayWidth / 2, displayHeight / 2,
                calibri_numbers, sleepStr, Gfx.TEXT_JUSTIFY_CENTER);
            return;
        }

        // ── Calcular posiciones relativas ─────────────────────────────────────
        var xOffset   = (displayHeight == 180) ? 12 : 0;
        xOffset = mirrored ? -xOffset : xOffset;
        var cx        = displayWidth / 2 + xOffset;
        var xLeft     = cx - 5;
        var xRight    = cx + 5;

        var yDate     = (displayHeight * 0.87).toNumber();
        var yHour     = _getYHour(displayHeight);
        var yMin      = _getYMin(displayHeight);
        // var yBat      = (displayHeight * 0.19).toNumber();
        var yNotif    = (displayHeight * 0.46).toNumber();
        var yAlt      = (displayHeight * 0.52).toNumber(); // Ahora calculado como porcentaje (52%)
        // var ySteps    = (displayHeight * 0.37).toNumber();
        var yHr       = (displayHeight * 0.40).toNumber();
        var yPhone    = (displayHeight * 0.40).toNumber();
        // var lineTop   = (displayHeight * 0.17).toNumber();
        // var lineBot   = (displayHeight * 0.67).toNumber();
        var arcRadius = (displayHeight * 0.11).toNumber();
        var arcCY     = (displayHeight * 0.84).toNumber();
        var arcBatX   = (displayWidth  * 0.27).toNumber();
        // var arcStepX  = (displayWidth  * 0.73).toNumber();

        // Guardar area de clip para onPartialUpdate (columna izquierda: hora/min)
        _timeClipX = 0;
        _timeClipY = yHour;
        _timeClipW = cx;
        _timeClipH = (displayHeight * 0.70).toNumber() - yHour;

        // ── Calcular datos dinámicos ──────────────────────────────────────────
        var clockTime  = Sys.getClockTime();
        var hour       = clockTime.hour;
        if (!Sys.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        var strhour = hour.format("%02d");
        var strmin  = clockTime.min.format("%02d");
        var curMin  = clockTime.min;

        var today      = Greg.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateString = Lang.format("$1$ $2$ $3$",
            [today.day_of_week, today.day, today.month]);

        var stats    = Sys.getSystemStats();
        var batPct   = stats.battery.toNumber();
        var charging = (stats has :charging) && stats.charging;
        var batColor = (batPct <= 20) ? Gfx.COLOR_RED
                     : (batPct <= 50) ? Gfx.COLOR_YELLOW
                     : Gfx.COLOR_GREEN;
        var batStr   = charging ? (batPct.toString() + "% +") : (batPct.toString() + "%");

        var altInfo = Act.getActivityInfo().altitude;
        var altStr;
        if (altInfo != null) {
            if (Sys.getDeviceSettings().elevationUnits == Sys.UNIT_METRIC) {
                altStr = altInfo.toFloat().format("%.0f") + " m";
            } else {
                altStr = (altInfo.toFloat() * 3.2808399).format("%.0f") + " ft";
            }
        } else {
            altStr = "-- m";
        }

        var activity   = Actmon.getInfo();
        var steps      = activity.steps;
        var stepsGoal  = (activity.stepGoal == 0) ? 5000 : activity.stepGoal;
        var stepsPct   = (steps.toFloat() / stepsGoal.toFloat() * 100.0).toNumber();
        if (stepsPct > 100) { stepsPct = 100; }
        var stepsColor = (stepsPct >= 100) ? Gfx.COLOR_GREEN : Gfx.COLOR_WHITE;

        // Calcular número de pisos subidos (FLOOR)
        var FLOOR = 0;
        // Preferir propiedad nativa si existe en la estructura de actividad
        if (activity != null) {
            if (activity has :floors) {
                FLOOR = Math.round(activity.floors.toFloat());
            } else if (activity has :floorsAscended) {
                FLOOR = Math.round(activity.floorsAscended.toFloat());
            } else if (activity has :elevationGain) {
                // Suponemos ~3 metros por piso
                FLOOR = Math.round(activity.elevationGain.toFloat() / 3.0);
            }
        }
        // Asegurar entero no negativo
        if (FLOOR < 0) { FLOOR = 0; }
        // Fallback: si no hay dato nativo, estimar a partir de la altitud relativa
        if (FLOOR == 0) {
            if (altInfo != null) {
                var currentAlt = altInfo.toFloat();
                if (_startAltitude == null) {
                    _startAltitude = currentAlt;
                }
                var delta = currentAlt - _startAltitude;
                if (delta < 0) { delta = 0; }
                FLOOR = Math.round(delta / 3.0);
            }
        }

        // ── Redibujar capa estatica si el minuto cambio o el buffer esta invalidado
        if (_bufferDirty || curMin != _lastMinute) {
            _lastMinute  = curMin;
            _bufferDirty = false;
            // Si hay buffer: dibujar en el buffer. Si no: dibujar directamente en dc.
            var targetDc = (_bgBuffer != null) ? _bgBuffer.getDc() : dc;
            var staticLayout = {
                :xRight => xRight,
                :yDate => yDate, :yAlt => yAlt, :yMin => yMin,
                :yPhone => yPhone, :yNotif => yNotif,
                :arcRadius => arcRadius, :arcCY => arcCY, :arcBatX => arcBatX
            };
            var staticData = {
                :dateString => dateString,
                :batPct => batPct, :batColor => batColor, :batStr => batStr,
                :altStr => altStr,
                :steps => steps, :stepsGoal => stepsGoal, :stepsPct => stepsPct, :stepsColor => stepsColor,
                :floor => FLOOR
            };
            _drawStaticLayer(targetDc, staticLayout, staticData);
        }

        // ── Blitear buffer a pantalla (si existe) ─────────────────────────────
        if (_bgBuffer != null) {
            dc.drawBitmap(0, 0, _bgBuffer);
        }

        // ── Capa dinamica: hora y FC encima del fondo ─────────────────────────
        _drawDynamicLayer(dc, xLeft, yHour, yMin, xRight, yHr, strhour, strmin);
    }

    // ── onPartialUpdate: relojes AMOLED (Epix 2 / Venu 3 / FR265 / FR965…) ──
    // El sistema llama a este metodo cada SEGUNDO en dispositivos con pantalla
    // AMOLED. Solo actualizamos la zona de la hora usando un clip rectangle para
    // limitar los pixeles modificados y evitar burn-in.
    // onUpdate sigue ejecutandose cada minuto y redibuja todo el fondo.
    function onPartialUpdate(dc) {
        if (_isSleeping) { return; }

        var clockTime = Sys.getClockTime();
        var hour = clockTime.hour;
        if (!Sys.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        var strhour = hour.format("%02d");
        var strmin  = clockTime.min.format("%02d");

        // Aplicar clip a la columna izquierda (zona hora/minutos)
        if (_timeClipW > 0 && _timeClipH > 0) {
            dc.setClip(_timeClipX, _timeClipY, _timeClipW, _timeClipH);
        }

        // Limpiar esa zona con negro antes de redibujar
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.fillRectangle(_timeClipX, _timeClipY, _timeClipW, _timeClipH);

        // Redibujar hora y minutos con las coordenadas calculadas en onUpdate
        var xOffset = (_displayHeight == 180) ? 12 : 0;
        xOffset = mirrored ? -xOffset : xOffset;
        var cx    = _displayWidth / 2 + xOffset;
        var yHour = _getYHour(_displayHeight);
        var yMin  = _getYMin(_displayHeight);

        dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
        dc.drawText(_getXMin(_displayWidth), yHour, calibri_numbers, strhour, Gfx.TEXT_JUSTIFY_CENTER);
        dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawText(_getXMin(_displayWidth), yMin,  calibri_numbers, strmin,  Gfx.TEXT_JUSTIFY_CENTER);

        dc.clearClip();
    }

    function onHide() {
    }

    // Al entrar en modo sleep: activar flag e invalidar buffer
    function onEnterSleep() {
        _isSleeping  = true;
        _bufferDirty = true;
        WatchUi.requestUpdate();
    }

    // Al salir del modo sleep: forzar redibujado completo
    function onExitSleep() {
        _isSleeping  = false;
        _bufferDirty = true;
        WatchUi.requestUpdate();
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    // Retorna la coordenada Y para los minutos (porcentaje desde arriba).
    function _getYMin(displayHeight) {
        return (displayHeight * 0.40).toNumber();
    }

    // Retorna la coordenada X para la columna de hora/minutos (porcentaje desde la izquierda).
    function _getXMin(displayWidth) {
        return (displayWidth * 0.35).toNumber();
    }

    // Retorna la coordenada X para la columna derecha (60% desde la izquierda).
    function _getXRight(displayWidth) {
        return (displayWidth * 0.60).toNumber();
    }

    // Retorna la coordenada Y para la hora (porcentaje desde arriba).
    function _getYHour(displayHeight) {
        return (displayHeight * 0.14).toNumber();
    }


    // Dibuja un arco de progreso sobre cualquier DC (buffer o pantalla real).
    // Fondo completo en gris oscuro; relleno coloreado proporcional a value/maxValue.
    function _drawProgressArcOnDc(targetDc, x, y, radius, value, maxValue, color) {
        targetDc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
        targetDc.drawArc(x, y, radius, Graphics.ARC_CLOCKWISE, 90, -270);
        if (maxValue > 0 && value > 0) {
            var pct = value.toFloat() / maxValue.toFloat();
            if (pct > 1.0) { pct = 1.0; }
            var sweep = (pct * 360.0).toNumber();
            targetDc.setColor(color, Gfx.COLOR_TRANSPARENT);
            targetDc.drawArc(x, y, radius, Graphics.ARC_CLOCKWISE, 90, 90 - sweep);
        }
    }

    // Dibuja un arco de progreso personalizado para el bisel, permitiendo definir
    // el ángulo de inicio y la longitud total del arco (puede envolver por 0º).
    function _drawBezelProgress(targetDc, x, y, radius, value, maxValue, color, startAngle, totalSweep) {
        // Fondo del arco (porción no rellenada) - usar color gris oscuro por defecto
        var bgColor = Gfx.COLOR_DK_GRAY;
        // drawArc expects (startAngle, endAngle) and we draw clockwise, so compute
        // endAngle = startAngle - sweepDegrees (can be negative)
        var endAngleBg = (startAngle - totalSweep).toNumber();
        targetDc.setColor(bgColor, Gfx.COLOR_TRANSPARENT);
        targetDc.drawArc(x, y, radius, Graphics.ARC_CLOCKWISE, startAngle, endAngleBg);
        if (maxValue > 0 && value > 0) {
            var pct = value.toFloat() / maxValue.toFloat();
            if (pct > 1.0) { pct = 1.0; }
            var sweepDeg = (totalSweep * pct).toNumber();
            var endAngleFill = (startAngle - sweepDeg).toNumber();
            targetDc.setColor(color, Gfx.COLOR_TRANSPARENT);
            targetDc.drawArc(x, y, radius, Graphics.ARC_CLOCKWISE, startAngle, endAngleFill);
        }
    }

    // Alias publico mantenido por compatibilidad
    function drawProgressArc(dc, x, y, radius, value, maxValue, color) {
        _drawProgressArcOnDc(dc, x, y, radius, value, maxValue, color);
    }

    // Icono de sobre para notificaciones (uso futuro)
    function drawNotificationSymbol(dc, x, y) {
        dc.drawRectangle(x, y - 10, 15, 10);
        dc.drawLine(x, y - 10, x + 8, y - 2);
        dc.drawLine(x + 7, y - 2, x + 15, y - 10);
    }

}

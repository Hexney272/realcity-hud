/* ==========================================================================
   RealCity HUD - app.js
   NUI üzenetkezelés, gyűrű/sáv animációk, pénz popup
   ========================================================================== */

(function () {
    'use strict';

    const $ = (id) => document.getElementById(id);
    const hud = $('hud');

    let speedUnit = 'kmh';
    let modules = { status: true, money: true, server: true, vehicle: true, voice: true };
    let currency = { cash: 'Ft', premium: 'RC' };

    // Az óra skála maximuma (km/h vagy mph). 260 km/h ~ realisztikus.
    const GAUGE_MAX = { kmh: 260, mph: 160 };
    const GAUGE_STEP = { kmh: 20, mph: 10 };   // fő beosztás
    const SWEEP = 270;                         // foknyi elfordulás (0 -> max)
    const START_ANGLE = -135;                  // 0 érték szöge (felfelé = 0)
    const RPM_REDLINE = 80;                    // efölött piros skála
    const ARC_LEN = 433.5;                     // 270° ív hossza r=92-nél

    // ---- Segédfüggvények ----------------------------------------------------

    const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));

    // Érték -> mutató szög (fok)
    function valueToAngle(v, max) {
        return START_ANGLE + (clamp(v, 0, max) / max) * SWEEP;
    }

    // Az analóg óra skálabeosztásának felépítése (egyszer, init-kor)
    function buildGauge() {
        const g = $('gauge-ticks');
        if (!g || g.childElementCount > 0) return;
        const NS = 'http://www.w3.org/2000/svg';
        const max = GAUGE_MAX[speedUnit];
        const step = GAUGE_STEP[speedUnit];
        const minorStep = step / 2;

        for (let v = 0; v <= max; v += minorStep) {
            const major = v % step === 0;
            const a = valueToAngle(v, max) * Math.PI / 180;
            const sin = Math.sin(a), cos = Math.cos(a);
            const rOuter = 88;
            const rInner = major ? 76 : 82;

            const line = document.createElementNS(NS, 'line');
            line.setAttribute('x1', 100 + rOuter * sin);
            line.setAttribute('y1', 100 - rOuter * cos);
            line.setAttribute('x2', 100 + rInner * sin);
            line.setAttribute('y2', 100 - rInner * cos);
            // pirosvonal a skála felső ~80%-a felett
            const isRed = (v / max) * 100 >= RPM_REDLINE && major;
            line.setAttribute('class', 'tick' + (major ? ' major' : '') + (isRed ? ' redline' : ''));
            g.appendChild(line);

            if (major) {
                const rl = 64;
                const t = document.createElementNS(NS, 'text');
                t.setAttribute('x', 100 + rl * sin);
                t.setAttribute('y', 100 - rl * cos);
                t.setAttribute('class', 'tick-label');
                t.textContent = v;
                g.appendChild(t);
            }
        }
    }

    function fmtMoney(n, suffix) {
        suffix = suffix || currency.cash;
        // magyar formátum: szóközös ezres tagolás
        return Number(n || 0).toLocaleString('hu-HU') + ' ' + suffix;
    }

    // státusz szín a kitöltés alapján (alacsony = piros)
    function statColor(stat, pct) {
        const css = getComputedStyle(document.documentElement);
        const green = css.getPropertyValue('--green').trim();
        const blue  = css.getPropertyValue('--blue').trim();
        const gold  = css.getPropertyValue('--gold').trim();
        const red   = css.getPropertyValue('--red').trim();
        const armor = css.getPropertyValue('--armor').trim();

        if (pct <= 20) return red;
        switch (stat) {
            case 'health':  return green;
            case 'armor':   return armor;
            case 'hunger':  return gold;
            case 'thirst':  return blue;
            case 'stamina': return green;
            case 'oxygen':  return blue;
            default:        return green;
        }
    }

    function setRing(stat, value) {
        const ring = document.querySelector(`.status-ring[data-stat="${stat}"]`);
        const valEl = $('st-' + stat);
        if (!ring) return;
        const pct = clamp(Math.round(value), 0, 100);
        ring.style.setProperty('--pct', pct);
        ring.style.setProperty('--col', statColor(stat, pct));
        // alacsony érték -> pulzáló figyelmeztetés
        if (pct <= 20) ring.classList.add('low');
        else ring.classList.remove('low');
        if (valEl) valEl.textContent = pct;
    }

    // ---- INIT (téma + config a clienttől) -----------------------------------

    function applyTheme(theme) {
        if (!theme) return;
        const root = document.documentElement;
        if (theme.green) root.style.setProperty('--green', theme.green);
        if (theme.blue)  root.style.setProperty('--blue',  theme.blue);
        if (theme.gold)  root.style.setProperty('--gold',  theme.gold);
        if (theme.red)   root.style.setProperty('--red',   theme.red);
        if (theme.armor) root.style.setProperty('--armor', theme.armor);
    }

    function applyModules(mods) {
        if (!mods) return;
        modules = Object.assign(modules, mods);
        toggleSection('server',  modules.server);
        toggleSection('money',   modules.money);
        toggleSection('status',  modules.status);
        // vehicle láthatóságát a jármű adat vezérli
    }

    function toggleSection(id, on) {
        const el = $(id);
        if (el) el.style.display = on ? '' : 'none';
    }

    // ---- PÉNZ popup ---------------------------------------------------------

    function moneyPopup(accKey, delta) {
        if (!delta) return;
        const pop = $('pop-' + accKey);
        if (!pop) return;
        const sign = delta > 0 ? '+' : '-';
        const suffix = accKey === 'rc' ? currency.premium : currency.cash;
        pop.textContent = sign + fmtMoney(Math.abs(delta), suffix);
        pop.classList.remove('up', 'down', 'show');
        void pop.offsetWidth; // reflow -> animáció újraindul
        pop.classList.add(delta > 0 ? 'up' : 'down', 'show');
    }

    // ---- Üzenetkezelő -------------------------------------------------------

    const handlers = {
        init(d) {
            applyTheme(d.theme);
            applyModules(d.modules);
            speedUnit = d.speedUnit === 'mph' ? 'mph' : 'kmh';
            if (d.currency) currency = Object.assign(currency, d.currency);
            $('veh-unit').textContent = speedUnit === 'mph' ? 'mph' : 'km/h';
            $('money-cash').textContent  = fmtMoney(0);
            $('money-bank').textContent  = fmtMoney(0);
            $('money-black').textContent = fmtMoney(0);
            $('money-rc').textContent    = fmtMoney(0, currency.premium);
            buildGauge();
        },

        visibility(d) {
            if (d.visible) hud.classList.remove('hidden');
            else hud.classList.add('hidden');
        },

        status(d) {
            setRing('health',  d.health);
            setRing('armor',   d.armor);
            setRing('hunger',  d.hunger);
            setRing('thirst',  d.thirst);
            setRing('stamina', d.stamina);

            const oxyRing = $('ring-oxygen');
            if (d.underwater) {
                oxyRing.classList.remove('hidden');
                setRing('oxygen', d.oxygen);
            } else {
                oxyRing.classList.add('hidden');
            }
        },

        voice(d) {
            const ring = $('ring-voice');
            if (!ring) return;
            if (d.talking) ring.classList.add('talking');
            else ring.classList.remove('talking');
        },

        money(d) {
            $('money-cash').textContent  = fmtMoney(d.cash);
            $('money-bank').textContent  = fmtMoney(d.bank);
            $('money-black').textContent = fmtMoney(d.black);
            $('money-rc').textContent    = fmtMoney(d.rc, currency.premium);
            moneyPopup('cash',  d.deltaCash);
            moneyPopup('bank',  d.deltaBank);
            moneyPopup('black', d.deltaBlack);
            moneyPopup('rc',    d.deltaRc);
        },

        server(d) {
            $('srv-players').textContent = d.players != null ? d.players : 0;
            $('srv-max').textContent = d.maxPlayers != null ? d.maxPlayers : 48;
            $('srv-id').textContent = d.serverId != null ? d.serverId : '--';
        },

        level(d) {
            if (d.level != null) $('lvl-num').textContent = d.level;
            const xp = Number(d.xp || 0);
            const next = Number(d.xpNext || 0);
            const pct = next > 0 ? clamp((xp / next) * 100, 0, 100) : 0;
            $('lvl-bar').style.width = pct + '%';
            $('lvl-xp').textContent = xp.toLocaleString('hu-HU') + ' / ' + next.toLocaleString('hu-HU');
        },

        vehicle(d) {
            const veh = $('vehicle');
            if (!d.inVehicle || !modules.vehicle) {
                veh.classList.add('hidden');
                return;
            }
            veh.classList.remove('hidden');

            // digitális kijelző
            $('veh-speed').textContent = d.speed;

            // analóg mutató (tű) forgatása
            const max = GAUGE_MAX[speedUnit];
            const ang = valueToAngle(d.speed, max);
            $('veh-needle').style.transform = `rotate(${ang}deg)`;

            // RPM ív kitöltése (stroke-dashoffset)
            const rpm = clamp(d.rpm, 0, 100) / 100;
            $('veh-rpm-arc').style.strokeDashoffset = (ARC_LEN * (1 - rpm)).toFixed(1);

            // fokozat: -1 hátra (R), 0 üres (N)
            let gear = 'N';
            if (d.gear === 0) gear = 'N';
            else if (d.gear < 0) gear = 'R';
            else gear = String(d.gear);
            $('veh-gear').textContent = gear;

            const fuel = clamp(d.fuel, 0, 100);
            $('veh-fuel').textContent = fuel + '%';
            $('veh-fuel-bar').style.width = fuel + '%';

            const eng = clamp(d.engineHealth, 0, 100);
            $('veh-engine').textContent = eng + '%';
            $('veh-engine-bar').style.width = eng + '%';

            const belt = $('veh-seatbelt');
            if (d.seatbelt) {
                belt.classList.add('on'); belt.classList.remove('off');
                belt.textContent = 'ÖV BE';
            } else {
                belt.classList.add('off'); belt.classList.remove('on');
                belt.textContent = 'ÖV KI';
            }
        },
    };

    window.addEventListener('message', (ev) => {
        const d = ev.data || {};
        const fn = handlers[d.action];
        if (fn) fn(d);
    });

    // ---- Jelezzük a cliensnek, hogy a NUI kész ------------------------------

    function notifyReady() {
        const name = (window.GetParentResourceName && GetParentResourceName()) || 'realcity-hud';
        fetch(`https://${name}/ready`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({}),
        }).catch(() => { /* böngészős előnézetben nincs NUI endpoint */ });
    }

    if (document.readyState === 'complete' || document.readyState === 'interactive') {
        notifyReady();
    } else {
        document.addEventListener('DOMContentLoaded', notifyReady);
    }
})();

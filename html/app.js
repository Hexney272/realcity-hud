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

    // ---- Segédfüggvények ----------------------------------------------------

    const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));

    function fmtMoney(n) {
        return '$' + Number(n || 0).toLocaleString('en-US');
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
        pop.textContent = sign + fmtMoney(Math.abs(delta));
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
            $('veh-unit').textContent = speedUnit === 'mph' ? 'mph' : 'km/h';
            if (d.server && d.server.name) {
                // logó már statikus; itt csak ha egyedi név kell
            }
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
            moneyPopup('cash',  d.deltaCash);
            moneyPopup('bank',  d.deltaBank);
            moneyPopup('black', d.deltaBlack);
        },

        server(d) {
            $('srv-players').textContent = d.players != null ? d.players : 0;
            $('srv-max').textContent = d.maxPlayers != null ? d.maxPlayers : 48;
            $('srv-id').textContent = d.serverId != null ? d.serverId : '--';
        },

        vehicle(d) {
            const veh = $('vehicle');
            if (!d.inVehicle || !modules.vehicle) {
                veh.classList.add('hidden');
                return;
            }
            veh.classList.remove('hidden');

            $('veh-speed').textContent = d.speed;
            $('veh-rpm').style.width = clamp(d.rpm, 0, 100) + '%';

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
                belt.textContent = '🔰 ÖV BE';
            } else {
                belt.classList.add('off'); belt.classList.remove('on');
                belt.textContent = '🔰 ÖV KI';
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

# -*- coding: utf-8 -*-
"""
DevEx Auto-Trade Tool
Grabs accounts from folder, assigns to device, enables for trading.
Script handles moving to completion folder + disabling when done.
"""

import requests
import time
import urllib3
import os
import sys
import traceback
import threading
import json
from datetime import datetime

urllib3.disable_warnings()

CONFIG_FILE = "harvest_config.json"

DEFAULT_CONFIG = {
    "farmsync_api_key":   "",
    "trade_config_id":    "",
    "origin_folder_id":   "",
    "batch_size":         30,
    "check_interval":     8,
    "config_change_delay": 4,
    "enable_delay":       3,
    "max_retries":        3,
    "webhook_url":        ""
}

def load_config():
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, 'r') as f:
                return {**DEFAULT_CONFIG, **json.load(f)}
        except:
            return DEFAULT_CONFIG.copy()
    return DEFAULT_CONFIG.copy()

def save_config(cfg):
    try:
        with open(CONFIG_FILE, 'w') as f:
            json.dump(cfg, f, indent=2)
        return True
    except Exception as e:
        print(f"Failed to save config: {e}")
        return False

# ============== COLORS ==============

class C:
    GREEN  = '\033[38;5;46m'
    DGREEN = '\033[38;5;22m'
    LIME   = '\033[38;5;118m'
    BLUE   = '\033[38;5;51m'
    PINK   = '\033[38;5;201m'
    YELLOW = '\033[38;5;226m'
    PURPLE = '\033[38;5;93m'
    RED    = '\033[38;5;196m'
    ORANGE = '\033[38;5;208m'
    BOLD   = '\033[1m'
    DIM    = '\033[2m'
    ENDC   = '\033[0m'

def clear():
    os.system('cls' if os.name == 'nt' else 'clear')

def banner():
    print(f"""{C.GREEN}
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║  {C.BOLD}{C.BLUE}██╗  ██╗ █████╗ ██████╗ ██╗   ██╗███████╗███████╗████████╗{C.ENDC}{C.GREEN}     ║
║  {C.BOLD}{C.BLUE}██║  ██║██╔══██╗██╔══██╗██║   ██║██╔════╝██╔════╝╚══██╔══╝{C.ENDC}{C.GREEN}     ║
║  {C.BOLD}{C.PINK}███████║███████║██████╔╝██║   ██║█████╗  ███████╗   ██║   {C.ENDC}{C.GREEN}      ║
║  {C.BOLD}{C.PINK}██╔══██║██╔══██║██╔══██╗╚██╗ ██╔╝██╔══╝  ╚════██║   ██║   {C.ENDC}{C.GREEN}     ║
║  {C.BOLD}{C.PURPLE}██║  ██║██║  ██║██║  ██║ ╚████╔╝ ███████╗███████║   ██║   {C.ENDC}{C.GREEN}     ║
║  {C.BOLD}{C.PURPLE}╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚══════╝   ╚═╝   {C.ENDC}{C.GREEN}   ║
║                                                                      ║
║        {C.YELLOW}Auto-Trade Tool v2.0{C.ENDC}{C.GREEN}                                      ║
║        {C.LIME}Folder-based · Device Assign · Live Monitor{C.ENDC}{C.GREEN}              ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝{C.ENDC}
""")

def sep():
    print(f"{C.DGREEN}{'━' * 72}{C.ENDC}")

def loading(msg, duration=1):
    frames = ['⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏']
    end = time.time() + duration
    i = 0
    while time.time() < end:
        print(f'\r{C.BLUE}[{frames[i % len(frames)]}]{C.ENDC} {msg}', end='', flush=True)
        time.sleep(0.1)
        i += 1
    print(f'\r{C.GREEN}[✓]{C.ENDC} {msg}')

# ============== LOGGING ==============

LOG_FILE = "harvest_trade.log"
ERR_FILE = "harvest_errors.log"

def log(msg, level="INFO"):
    ts = datetime.now().strftime("%H:%M:%S")
    colors = {"INFO": C.BLUE, "SUCCESS": C.GREEN, "WARNING": C.ORANGE, "ERROR": C.RED}
    emojis = {"INFO": "ℹ️ ", "SUCCESS": "✅", "WARNING": "⚠️ ", "ERROR": "❌"}
    color = colors.get(level, C.ENDC)
    emoji = emojis.get(level, "💬")
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(f"[{ts}] [{level}] {msg}\n")
    print(f"{C.DIM}[{ts}]{C.ENDC} {color}{emoji} {msg}{C.ENDC}")

def log_err(err, ctx=""):
    ts = datetime.now().strftime("%H:%M:%S")
    msg = f"ERROR in {ctx}: {str(err)}\n{traceback.format_exc()}"
    with open(ERR_FILE, "a", encoding="utf-8") as f:
        f.write(f"\n{'='*70}\n[{ts}] {msg}\n{'='*70}\n")
    print(f"{C.RED}❌ ERROR:{C.ENDC} {str(err)}")

# ============== API ==============

sess = requests.Session()
sess.verify = False
BASE = "https://api.farmsync.cloud/api"

def make_headers(api_key):
    return {
        'Authorization': f'Bearer {api_key}',
        'Content-Type': 'application/json'
    }

def api_retry(func, retries=3):
    for attempt in range(retries):
        try:
            return func()
        except Exception as e:
            if attempt < retries - 1:
                time.sleep(2 ** attempt)
            else:
                log_err(e, "api_retry")
    return None

def get_devices(api_key):
    def _f():
        r = sess.get(f"{BASE}/devices", headers=make_headers(api_key), timeout=30)
        return r.json() if r.status_code == 200 else []
    return api_retry(_f) or []

def get_folder_accounts(api_key, folder_id):
    """Get all accounts in a specific folder"""
    def _f():
        r = sess.get(f"{BASE}/self/folders/{folder_id}/accounts",
                     headers=make_headers(api_key), timeout=30)
        if r.status_code == 200:
            data = r.json()
            return data.get('accounts') or []
        return []
    return api_retry(_f) or []

def get_account(api_key, username):
    def _f():
        r = sess.get(f"{BASE}/self/accounts/{username}",
                     headers=make_headers(api_key), timeout=30)
        return r.json() if r.status_code == 200 else None
    return api_retry(_f)

def get_folders(api_key):
    def _f():
        r = sess.get(f"{BASE}/self/folders/", headers=make_headers(api_key), timeout=30)
        return r.json() if r.status_code == 200 else []
    return api_retry(_f) or []

def assign_and_enable(api_key, username, device_id, config_id, cfg):
    """Assign device, set trade config, enable account"""
    delay        = cfg.get('config_change_delay', 4)
    enable_delay = cfg.get('enable_delay', 3)

    def _f():
        url  = f"{BASE}/self/accounts/{username}"
        hdrs = make_headers(api_key)

        # Step 1: Disable first (safety)
        sess.put(url, headers=hdrs, json={'enabled': False}, timeout=30)
        time.sleep(delay)

        # Step 2: Assign device + set config
        sess.put(url, headers=hdrs, json={
            'enabled':   False,
            'device_id': device_id,
            'config_id': config_id
        }, timeout=30)
        time.sleep(delay)

        # Step 3: Enable
        r = sess.put(url, headers=hdrs, json={
            'enabled':   True,
            'device_id': device_id,
            'config_id': config_id
        }, timeout=30)
        time.sleep(enable_delay)
        return r.status_code == 200

    return api_retry(_f) or False

def is_account_disabled(api_key, username):
    acc = get_account(api_key, username)
    if acc:
        return not acc.get('enabled', True)
    return False

def send_webhook(url, msg):
    if not url:
        return
    try:
        requests.post(url, json={"content": msg}, timeout=10)
    except:
        pass

# ============== SETUP WIZARD ==============

def run_setup_wizard(cfg):
    clear()
    banner()

    print(f"{C.BOLD}{C.YELLOW}╔══════════════════════════════════════════╗{C.ENDC}")
    print(f"{C.BOLD}{C.YELLOW}║         🔧 SETUP WIZARD 🔧               ║{C.ENDC}")
    print(f"{C.BOLD}{C.YELLOW}╚══════════════════════════════════════════╝{C.ENDC}\n")
    print(f"{C.DIM}Config saved to {CONFIG_FILE} and auto-loaded next run.{C.ENDC}\n")
    sep()

    fields = [
        ('farmsync_api_key', '1/3', C.BLUE,   'FarmSync API Key',
         'Dashboard → API Keys'),
        ('trade_config_id',  '2/3', C.PINK,   'Trade Config ID',
         'The config that runs the trade script on accounts'),
        ('origin_folder_id', '3/3', C.PURPLE, 'Origin Folder ID',
         'The folder where accounts wait to be traded'),
    ]

    for key, step, color, label, hint in fields:
        current = cfg.get(key, '')
        print(f"\n{C.BOLD}{color}[{step}]{C.ENDC} {C.BOLD}{label}{C.ENDC}")
        print(f"      {C.DIM}{hint}{C.ENDC}")

        # Show folder list for origin folder step
        if key == 'origin_folder_id' and cfg.get('farmsync_api_key'):
            try:
                folders = get_folders(cfg['farmsync_api_key'])
                if folders:
                    print(f"\n      {C.BOLD}Your folders:{C.ENDC}")
                    for f in folders:
                        fname = f.get('folder_name') or 'Unnamed'
                        fid   = f.get('id', '')
                        # Show child folders too
                        from_id = f.get('from_child_folder_id', '')
                        to_id   = f.get('to_child_folder_id', '')
                        print(f"      {C.LIME}{fname}{C.ENDC}")
                        print(f"        Parent : {C.DIM}{fid[:32]}...{C.ENDC}")
                        if from_id:
                            print(f"        From   : {C.DIM}{from_id[:32]}...{C.ENDC}")
                        if to_id:
                            print(f"        To     : {C.DIM}{to_id[:32]}...{C.ENDC}")
                    print()
            except:
                pass

        if current:
            print(f"      {C.DIM}Current: {current[:32]}...{C.ENDC}")
        val = input(f"      {C.BOLD}{C.GREEN}>>> Enter value (ENTER to keep):{C.ENDC} ").strip()
        if val:
            cfg[key] = val

    print(f"\n{C.BOLD}{C.LIME}[Optional]{C.ENDC} {C.BOLD}Discord Webhook URL{C.ENDC}")
    val = input(f"      {C.BOLD}{C.GREEN}>>> Webhook (ENTER to skip):{C.ENDC} ").strip()
    if val:
        cfg['webhook_url'] = val

    sep()
    missing = [f for f in ['farmsync_api_key', 'trade_config_id', 'origin_folder_id']
               if not cfg.get(f)]
    if missing:
        print(f"\n{C.RED}❌ Missing: {', '.join(missing)}{C.ENDC}")
        input("\nPress ENTER to retry...")
        return run_setup_wizard(cfg)

    save_config(cfg)
    print(f"\n{C.GREEN}✅ Config saved!{C.ENDC}")
    time.sleep(1.5)
    return cfg

def check_and_setup(cfg):
    needs = not all([cfg.get('farmsync_api_key'),
                     cfg.get('trade_config_id'),
                     cfg.get('origin_folder_id')])
    if needs:
        cfg = run_setup_wizard(cfg)
    return cfg

# ============== TRADE MANAGER ==============

class TradeManager:
    def __init__(self, cfg, selected_device):
        self.cfg            = cfg
        self.api_key        = cfg['farmsync_api_key']
        self.config_id      = cfg['trade_config_id']
        self.origin_folder  = cfg['origin_folder_id']
        self.device_id      = selected_device['id']
        self.device_name    = selected_device['device_name']
        self.batch_size     = cfg.get('batch_size', 30)
        self.check_interval = cfg.get('check_interval', 8)
        self.webhook_url    = cfg.get('webhook_url', '')

        self.queue     = []
        self.active    = []
        self.completed = []
        self.failed    = []

        self.lock               = threading.Lock()
        self._dashboard_printed = False
        self._last_dashboard    = 0

    def load_queue(self):
        log(f"Loading accounts from origin folder...", "INFO")

        accounts = get_folder_accounts(self.api_key, self.origin_folder)
        if not accounts:
            log("No accounts found in origin folder!", "ERROR")
            return False

        for acc in accounts:
            username   = acc.get('username')
            is_enabled = acc.get('enabled', False)
            config_id  = acc.get('config_id', '')

            if is_enabled and config_id == self.config_id:
                with self.lock:
                    self.active.append(username)
                log(f"{username} - already trading, monitoring", "INFO")
            elif is_enabled:
                log(f"{username} - enabled with different config, skipping", "WARNING")
            else:
                with self.lock:
                    self.queue.append(username)

        total = len(self.queue) + len(self.active)

        print(f"\n{C.GREEN}╔══════════════════════════════════════════╗{C.ENDC}")
        print(f"{C.GREEN}║  📊 Accounts Loaded from Origin Folder   ║{C.ENDC}")
        print(f"{C.GREEN}╠══════════════════════════════════════════╣{C.ENDC}")
        print(f"{C.GREEN}║  Total in folder : {len(accounts):>3}                    ║{C.ENDC}")
        print(f"{C.GREEN}║  Queued (ready)  : {len(self.queue):>3}                    ║{C.ENDC}")
        print(f"{C.GREEN}║  Already active  : {len(self.active):>3}                    ║{C.ENDC}")
        print(f"{C.GREEN}║  Device          : {self.device_name[:20]:<20}  ║{C.ENDC}")
        print(f"{C.GREEN}║  Batch size      : {self.batch_size:>3}                    ║{C.ENDC}")
        print(f"{C.GREEN}╚══════════════════════════════════════════╝{C.ENDC}\n")

        return total > 0

    def _start_account(self, username):
        try:
            log(f"{username} - Assigning to {self.device_name} + enabling...", "INFO")
            ok = assign_and_enable(
                self.api_key, username,
                self.device_id, self.config_id,
                self.cfg
            )
            with self.lock:
                if ok:
                    self.active.append(username)
                    log(f"{username} - Started trading on {self.device_name}", "SUCCESS")
                else:
                    self.failed.append(username)
                    log(f"{username} - Failed to start", "ERROR")
        except Exception as e:
            log_err(e, f"_start_account {username}")
            with self.lock:
                self.failed.append(username)

    def fill_slots(self):
        with self.lock:
            slots    = self.batch_size - len(self.active)
            to_start = []
            for _ in range(max(slots, 0)):
                if self.queue:
                    to_start.append(self.queue.pop(0))

        if not to_start:
            return

        log(f"Filling {len(to_start)} slot(s)...", "INFO")
        threads = [threading.Thread(target=self._start_account, args=(u,), daemon=True)
                   for u in to_start]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

    def check_completions(self):
        with self.lock:
            active_copy = list(self.active)

        for username in active_copy:
            try:
                if is_account_disabled(self.api_key, username):
                    log(f"{username} - Done trading! Slot freed.", "SUCCESS")
                    with self.lock:
                        if username in self.active:
                            self.active.remove(username)
                        self.completed.append(username)
                    send_webhook(self.webhook_url,
                        f"✅ **{username}** finished trading!")
            except Exception as e:
                log_err(e, f"check_completions {username}")

    def print_dashboard(self):
        now = time.time()
        if now - self._last_dashboard < 3:
            return
        self._last_dashboard = now

        with self.lock:
            n_active    = len(self.active)
            n_queued    = len(self.queue)
            n_completed = len(self.completed)
            n_failed    = len(self.failed)
            active_copy = list(self.active)

        total    = n_active + n_queued + n_completed + n_failed
        progress = int((n_completed / total * 46)) if total > 0 else 0
        bar      = f"{C.GREEN}{'█' * progress}{C.DIM}{'░' * (46 - progress)}{C.ENDC}"

        MAX_SHOWN  = 8
        DASH_HEIGHT = 22 + MAX_SHOWN
        if self._dashboard_printed:
            print(f"\033[{DASH_HEIGHT}A", end='')

        ts = datetime.now().strftime("%H:%M:%S")

        def row(content, width=69):
            import re
            plain = re.sub(r'\033\[[0-9;]*m', '', content)
            pad = width - len(plain)
            return f"{C.BLUE}║{C.ENDC}{content}{' ' * max(pad, 0)}{C.BLUE}║{C.ENDC}"

        print(f"\n{C.BLUE}╔{'═'*71}╗{C.ENDC}")
        print(row(f" {C.BOLD}{C.YELLOW}📊 LIVE DASHBOARD{C.ENDC}  {C.DIM}[{ts}]{C.ENDC}"))
        print(f"{C.BLUE}╠{'═'*71}╣{C.ENDC}")
        print(row(f" Progress: [{bar}] {n_completed}/{total}"))
        print(f"{C.BLUE}╠{'═'*71}╣{C.ENDC}")
        print(row(f"  {C.GREEN}✅ Completed : {n_completed:>4}{C.ENDC}"))
        print(row(f"  {C.YELLOW}🔄 Trading   : {n_active:>4}{C.ENDC}  / {self.batch_size} batch max"))
        print(row(f"  {C.BLUE}⏳ Queued    : {n_queued:>4}{C.ENDC}"))
        print(row(f"  {C.RED}❌ Failed    : {n_failed:>4}{C.ENDC}"))
        print(f"{C.BLUE}╠{'═'*71}╣{C.ENDC}")
        print(row(f"  {C.BOLD}Device: {self.device_name}{C.ENDC}"))
        print(row(f"  {C.BOLD}Currently Trading:{C.ENDC}"))

        shown = active_copy[:MAX_SHOWN]
        for uname in shown:
            print(row(f"    🟢 {uname}"))
        if n_active > MAX_SHOWN:
            print(row(f"    {C.DIM}... and {n_active - MAX_SHOWN} more{C.ENDC}"))
            for _ in range(MAX_SHOWN - 1):
                print(row(""))
        else:
            for _ in range(MAX_SHOWN - len(shown)):
                print(row(""))

        print(f"{C.BLUE}╠{'═'*71}╣{C.ENDC}")
        print(row(f"  {C.DIM}Batch: {self.batch_size} | Check: {self.check_interval}s | Ctrl+C to stop{C.ENDC}"))
        print(f"{C.BLUE}╚{'═'*71}╝{C.ENDC}")
        print()
        print()

        self._dashboard_printed = True

    def run(self):
        log("AUTO-TRADE STARTED", "SUCCESS")
        send_webhook(self.webhook_url,
            f"Auto-Trade started | {len(self.queue)} accounts | Batch: {self.batch_size} | Device: {self.device_name}")

        try:
            while True:
                self.check_completions()
                self.fill_slots()
                self.print_dashboard()

                with self.lock:
                    remaining = len(self.queue) + len(self.active)

                if remaining == 0:
                    break

                time.sleep(self.check_interval)

        except KeyboardInterrupt:
            log("Interrupted", "WARNING")
            raise

        print(f"\n{C.GREEN}{C.BOLD}╔════════════════════════════════════════╗{C.ENDC}")
        print(f"{C.GREEN}{C.BOLD}║   🎉 ALL ACCOUNTS PROCESSED!           ║{C.ENDC}")
        print(f"{C.GREEN}{C.BOLD}╠════════════════════════════════════════╣{C.ENDC}")
        print(f"{C.GREEN}{C.BOLD}║  ✅ Completed : {len(self.completed):>4}                    ║{C.ENDC}")
        print(f"{C.GREEN}{C.BOLD}║  ❌ Failed    : {len(self.failed):>4}                    ║{C.ENDC}")
        print(f"{C.GREEN}{C.BOLD}╚════════════════════════════════════════╝{C.ENDC}\n")

        send_webhook(self.webhook_url,
            f"🎉 All done! ✅ {len(self.completed)} completed | ❌ {len(self.failed)} failed")

# ============== DEVICE + START ==============

def select_device_and_start(cfg):
    clear()
    banner()

    loading("Fetching devices & folder accounts...", 1.5)

    devices = get_devices(cfg['farmsync_api_key'])
    if not devices:
        print(f"\n{C.RED}❌ No devices found!{C.ENDC}")
        input("\nPress ENTER...")
        return

    # Count accounts in origin folder
    folder_accounts = get_folder_accounts(cfg['farmsync_api_key'], cfg['origin_folder_id'])
    total_ready = sum(1 for a in folder_accounts if not a.get('enabled', False))
    total_active = sum(1 for a in folder_accounts if a.get('enabled', False))

    print(f"\n{C.BOLD}{C.YELLOW}╔══════════════════════════════════════════════════════╗{C.ENDC}")
    print(f"{C.BOLD}{C.YELLOW}║           📱 SELECT DEVICE TO TRADE ON              ║{C.ENDC}")
    print(f"{C.BOLD}{C.YELLOW}╚══════════════════════════════════════════════════════╝{C.ENDC}\n")

    print(f"  {C.BOLD}Origin folder:{C.ENDC} {C.DIM}{cfg['origin_folder_id'][:32]}...{C.ENDC}")
    print(f"  {C.BOLD}Accounts ready:{C.ENDC} {C.GREEN}{total_ready}{C.ENDC}  |  Active: {C.YELLOW}{total_active}{C.ENDC}\n")

    print(f"  {C.BOLD}{'No.':<5} {'Device Name':<30}{C.ENDC}")
    sep()
    for i, d in enumerate(devices, 1):
        print(f"  {C.BLUE}[{i}]{C.ENDC}   {C.LIME}{d['device_name']}{C.ENDC}")
    sep()

    choice = input(f"\n{C.BOLD}{C.GREEN}>>> Select device (number):{C.ENDC} ").strip()
    try:
        idx = int(choice) - 1
        if not (0 <= idx < len(devices)):
            raise ValueError()
        selected = devices[idx]
    except:
        print(f"{C.RED}❌ Invalid!{C.ENDC}")
        input("\nPress ENTER...")
        return

    # Batch size
    print(f"\n  {C.DIM}Private server fits ~35, recommend 30 max{C.ENDC}")
    batch_input = input(f"{C.BOLD}{C.PINK}>>> Batch size (ENTER for {cfg.get('batch_size', 30)}):{C.ENDC} ").strip()
    if batch_input:
        try:
            b = int(batch_input)
            if 1 <= b <= 35:
                cfg['batch_size'] = b
                save_config(cfg)
        except:
            pass

    # Summary
    print(f"\n{C.BOLD}{'━'*44}{C.ENDC}")
    print(f"{C.BOLD}📋 Summary:{C.ENDC}")
    print(f"   Device        : {selected['device_name']}")
    print(f"   Origin folder : ...{cfg['origin_folder_id'][-12:]}")
    print(f"   Trade config  : ...{cfg['trade_config_id'][-12:]}")
    print(f"   Ready accs    : {total_ready}")
    print(f"   Batch size    : {cfg['batch_size']}")
    print(f"{C.BOLD}{'━'*44}{C.ENDC}\n")

    confirm = input(f"{C.BOLD}{C.YELLOW}>>> Start? (yes/no):{C.ENDC} ").strip().lower()
    if confirm != 'yes':
        return

    print()
    mgr = TradeManager(cfg, selected)
    if mgr.load_queue():
        mgr.run()
    else:
        print(f"{C.RED}❌ No accounts found in origin folder!{C.ENDC}")
    input(f"\n{C.DIM}Press ENTER...{C.ENDC}")

# ============== SETTINGS ==============

def settings_menu(cfg):
    while True:
        clear()
        banner()
        print(f"{C.BOLD}{C.YELLOW}⚙️  SETTINGS{C.ENDC}\n")
        sep()
        print(f"\n  {C.BLUE}[1]{C.ENDC} FarmSync API Key   : {C.DIM}{(cfg.get('farmsync_api_key') or '')[:24] or 'Not set'}{C.ENDC}")
        print(f"  {C.PINK}[2]{C.ENDC} Trade Config ID    : {C.DIM}{(cfg.get('trade_config_id') or '')[:24] or 'Not set'}{C.ENDC}")
        print(f"  {C.PURPLE}[3]{C.ENDC} Origin Folder ID   : {C.DIM}{(cfg.get('origin_folder_id') or '')[:24] or 'Not set'}{C.ENDC}")
        print(f"  {C.LIME}[4]{C.ENDC} Default Batch Size : {C.BOLD}{cfg.get('batch_size', 30)}{C.ENDC}")
        print(f"  {C.YELLOW}[5]{C.ENDC} Check Interval     : {C.BOLD}{cfg.get('check_interval', 8)}s{C.ENDC}")
        print(f"  {C.BLUE}[6]{C.ENDC} Config Change Delay: {C.BOLD}{cfg.get('config_change_delay', 4)}s{C.ENDC}")
        print(f"  {C.PINK}[7]{C.ENDC} Enable Delay       : {C.BOLD}{cfg.get('enable_delay', 3)}s{C.ENDC}")
        print(f"  {C.LIME}[8]{C.ENDC} Webhook URL        : {C.DIM}{cfg.get('webhook_url') or 'Not set'}{C.ENDC}")
        print(f"\n  {C.GREEN}[9]{C.ENDC} 💾 Save & Back")
        print(f"  {C.RED}[0]{C.ENDC} 🔧 Run Setup Wizard\n")
        sep()

        choice = input(f"\n{C.BOLD}{C.GREEN}>>> Option:{C.ENDC} ").strip()
        prompts = {
            '1': ('farmsync_api_key',    'FarmSync API Key',           str, None),
            '2': ('trade_config_id',     'Trade Config ID',            str, None),
            '3': ('origin_folder_id',    'Origin Folder ID',           str, None),
            '4': ('batch_size',          'Batch Size (1-35)',          int, (1, 35)),
            '5': ('check_interval',      'Check Interval secs (3-60)', int, (3, 60)),
            '6': ('config_change_delay', 'Config Delay secs (1-15)',   int, (1, 15)),
            '7': ('enable_delay',        'Enable Delay secs (1-15)',   int, (1, 15)),
            '8': ('webhook_url',         'Webhook URL',                str, None),
        }
        if choice in prompts:
            key, label, cast, bounds = prompts[choice]
            val = input(f"  Enter {label}: ").strip()
            try:
                if val:
                    v = cast(val)
                    if bounds and not (bounds[0] <= v <= bounds[1]):
                        raise ValueError()
                    cfg[key] = v
                    print(f"  {C.GREEN}✅ Updated!{C.ENDC}")
            except:
                print(f"  {C.RED}❌ Invalid!{C.ENDC}")
            time.sleep(0.8)
        elif choice == '9':
            save_config(cfg)
            print(f"  {C.GREEN}✅ Saved!{C.ENDC}")
            time.sleep(0.8)
            break
        elif choice == '0':
            cfg = run_setup_wizard(cfg)
            break
        else:
            print(f"  {C.RED}❌ Invalid!{C.ENDC}")
            time.sleep(0.8)
    return cfg

# ============== LOGS ==============

def view_logs():
    clear()
    banner()
    print(f"{C.BOLD}{C.YELLOW}━━━ RECENT LOGS ━━━{C.ENDC}\n")
    if os.path.exists(LOG_FILE):
        with open(LOG_FILE, "r", encoding="utf-8") as f:
            lines = f.readlines()
        for line in lines[-40:]:
            print(f"{C.DIM}{line.strip()}{C.ENDC}")
    else:
        print(f"{C.ORANGE}⚠️  No logs yet{C.ENDC}")
    input(f"\n{C.DIM}Press ENTER...{C.ENDC}")

# ============== MAIN ==============

def main():
    cfg = load_config()
    cfg = check_and_setup(cfg)
    log("=== Auto-Trade Tool Started ===", "SUCCESS")

    while True:
        try:
            clear()
            banner()
            sep()

            ok = lambda k: bool(cfg.get(k))
            print(f"\n  "
                  f"{C.GREEN if ok('farmsync_api_key') else C.RED}{'✅' if ok('farmsync_api_key') else '❌'} API Key{C.ENDC}   "
                  f"{C.GREEN if ok('trade_config_id') else C.RED}{'✅' if ok('trade_config_id') else '❌'} Trade Config{C.ENDC}   "
                  f"{C.GREEN if ok('origin_folder_id') else C.RED}{'✅' if ok('origin_folder_id') else '❌'} Origin Folder{C.ENDC}\n")
            sep()

            print(f"\n  {C.BOLD}{C.BLUE}[1]{C.ENDC} {C.GREEN}🚀 Start Auto-Trade{C.ENDC}")
            print(f"  {C.BOLD}{C.PINK}[2]{C.ENDC} {C.YELLOW}📱 View Devices{C.ENDC}")
            print(f"  {C.BOLD}{C.PURPLE}[3]{C.ENDC} {C.LIME}📜 View Logs{C.ENDC}")
            print(f"  {C.BOLD}{C.YELLOW}[4]{C.ENDC} {C.BLUE}⚙️  Settings{C.ENDC}")
            print(f"  {C.BOLD}{C.RED}[5]{C.ENDC} {C.RED}🚪 Exit{C.ENDC}\n")
            sep()

            choice = input(f"\n{C.BOLD}{C.GREEN}>>> Select (1-5):{C.ENDC} ").strip()

            if choice == '1':
                if not all([ok('farmsync_api_key'), ok('trade_config_id'), ok('origin_folder_id')]):
                    print(f"\n{C.RED}❌ Setup incomplete! Go to Settings first.{C.ENDC}")
                    time.sleep(2)
                    continue
                select_device_and_start(cfg)

            elif choice == '2':
                clear()
                banner()
                loading("Fetching devices...", 1)
                devices = get_devices(cfg['farmsync_api_key'])
                if not devices:
                    print(f"{C.RED}❌ No devices!{C.ENDC}")
                else:
                    print(f"\n  {C.BOLD}{'No.':<5} {'Device Name':<30} {'ID'}{C.ENDC}")
                    sep()
                    for i, d in enumerate(devices, 1):
                        print(f"  {C.BLUE}[{i}]{C.ENDC}   {C.LIME}{d['device_name']:<30}{C.ENDC} {C.DIM}{d['id']}{C.ENDC}")
                input(f"\n{C.DIM}Press ENTER...{C.ENDC}")

            elif choice == '3':
                view_logs()

            elif choice == '4':
                cfg = settings_menu(cfg)

            elif choice == '5':
                log("=== Exited ===", "SUCCESS")
                print(f"\n{C.GREEN}👋 Goodbye!{C.ENDC}\n")
                sys.exit(0)
            else:
                print(f"\n{C.RED}❌ Invalid!{C.ENDC}")
                time.sleep(0.8)

        except KeyboardInterrupt:
            log("Interrupted", "WARNING")
            print(f"\n\n{C.ORANGE}⚠️  Interrupted{C.ENDC}")
            sys.exit(0)
        except Exception as e:
            log_err(e, "main loop")
            time.sleep(3)

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log_err(e, "startup")
        input("Press ENTER to exit...")
        sys.exit(1)

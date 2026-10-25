# Tasks (luci-app-tasks)

[简体中文](README.md) | English

A fool-proof task manager for OpenWrt / LuCI. Everything is done with
switches, dropdowns and time pickers — you never write a Linux command,
a cron expression or a script.

The package lives under **System → Tasks** (`admin/system/tasks`) and has
three pages:

| Page | What it does |
| --- | --- |
| Timed Tasks | Scheduled reboot, network restart, firewall restart, `/tmp` cleanup and memory cleanup, plus one-click "run now" buttons |
| Startup Services | Run a system service or a custom command after every boot, with a delay |
| Execution Log | Live log of scheduled and manual runs, with clear / download |

## Installation

### From Releases

1. Open the [Releases](https://github.com/Arthur97172/luci-app-tasks/releases)
   page and download the package for your firmware.
2. Upload it to the device (for example `/tmp`), then install:

   **OpenWrt 24.10 and older (opkg)**

   ```sh
   opkg install /tmp/luci-app-tasks_*.ipk

   #Optional, Simplified Chinese language pack:

   opkg install /tmp/luci-i18n-tasks-zh-cn_*.ipk
   ```

   **OpenWrt 25.12+ (apk)**

   ```sh
   apk add --allow-untrusted /tmp/luci-app-tasks-*.apk

   #Optional, Simplified Chinese language pack:

   apk add --allow-untrusted /tmp/luci-i18n-tasks-zh-cn-*.apk
   ```

3. Refresh LuCI; the entry appears under **System → Tasks**.

> Without the language pack the interface stays in English. The package is
> architecture independent (`all`), so one artifact works on ARM, x86, MIPS
> and every other platform.

### From source

```sh
cd openwrt
./scripts/feeds update -a
./scripts/feeds install -a
git clone https://github.com/Arthur97172/luci-app-tasks.git package/luci-app-tasks
make menuconfig     # LuCI → Applications → luci-app-tasks
make package/luci-app-tasks/compile V=s
```

The built packages end up in `bin/packages/<arch>/base/`.

## Usage

1. Open **System → Tasks → Timed Tasks**.
2. Pick the task in the **Task** drop-down at the top, switch **Enable** on,
   pick a schedule (every day / week / month, every hour, every few minutes or
   hours) and set the time.
3. Click **Save & Apply** at the bottom of the page. The application writes
   the cron entries for you; the status area at the top shows exactly what was
   written. Use **Save** first if you only want to stage the changes.
4. To run something immediately, use the **Run now** toolbar instead of
   waiting for the scheduled time.

**Startup Services** adds a service or command that runs after every boot;
**Execution Log** shows results and refreshes every 5 seconds.

## How it works

The frontend only writes friendly UCI options to `/etc/config/tasks`, e.g.
`tasks.reboot.mode=daily`, `tasks.reboot.hour=03`. Nothing is executed by the
browser.

`/etc/init.d/tasks` translates those options into real system artifacts:

- `/etc/crontabs/root` gets one line per enabled task, marked with
  `# luci-app-tasks:<action>`. Only those marked lines are ever removed, so
  cron jobs you added yourself are left alone.
- `/etc/tasks/startup.sh` is regenerated on every save and is run by the init
  script's `boot()` hook.
- `/usr/bin/tasks-handler` performs the actual action. It only accepts the
  fixed names `reboot`, `network`, `firewall`, `cleantmp` and `clearmem`;
  custom commands are read from UCI at run time and never embedded in cron.

Because cron lines are generated inside the init script (not by the browser),
the browser cannot inject arbitrary text into the crontab.

## Themes and compatibility

- Works in both the light and the dark variant of the LuCI theme, with no
  manual switch.
- Adapted to `luci-theme-bootstrap` (the default in OpenWrt 24.10 / 25.12) and
  to `luci-theme-argon` 2.x / 3.x.
- The stylesheet only uses CSS variables provided by the theme, with neutral
  fallbacks, so text stays readable even under an unknown theme.

## Safety notes

- Cleaning `/tmp` defaults to known LuCI / opkg caches only. The "older than"
  mode skips `*.pid` and `*.lock` files.
- Dropping memory caches is `sync && echo 3 > /proc/sys/vm/drop_caches`, which
  is safe but pointless to run very often.
- Startup service entries call `/etc/init.d/<service> start`; the service's
  own autostart setting is never modified.
- The log is capped at 500 lines and stored in `/etc/tasks/tasks.log`.

## Files

```
.
├── Makefile
├── htdocs/luci-static/resources/view/tasks.css
├── htdocs/luci-static/resources/view/tasks/
│   ├── scheduled.js
│   ├── startup.js
│   └── log.js
├── po/templates/tasks.pot
├── po/zh_Hans/tasks.po
└── root/
    ├── etc/config/tasks
    ├── etc/init.d/tasks
    ├── etc/uci-defaults/luci-tasks
    ├── usr/bin/tasks-handler
    ├── usr/lib/tasks/common.sh
    └── usr/share/{luci/menu.d,rpcd/acl.d}/luci-app-tasks.json
```

## Requirements

- OpenWrt 24.10 or newer with LuCI (JavaScript views, `luci-base`)
- `cron` (BusyBox `crond`); the init script enables and starts it when at
  least one generated job exists

## License

GPL-3.0-only

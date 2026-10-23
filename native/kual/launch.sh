#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
cd "$(dirname "$0")" || exit 1
mkdir -p data || exit 1
exec >>data/launch.log 2>&1
if [ ! -x ./pokepal ]; then
    eips 1 2 "PokePal executable missing. Copy the whole extension folder."
    exit 1
fi
if ! command -v lipc-wait-event >/dev/null 2>&1; then
    eips 1 2 "PokePal needs Kindle power events. See data/launch.log."
    exit 1
fi
# A second tap must not resume the first app's window manager on exit.
if ! mkdir data/launch.lock 2>/dev/null; then
    old_pid=$(cat data/launch.lock/pid 2>/dev/null)
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then exit 0; fi
    rm -f data/launch.lock/pid
    rmdir data/launch.lock 2>/dev/null || exit 1
    mkdir data/launch.lock || exit 1
fi
echo "$$" > data/launch.lock/pid
wm_pids=""
pillow_disabled=no
game_pid=""
cleanup() {
    trap - EXIT HUP INT TERM
    if [ -n "$game_pid" ]; then kill -TERM "$game_pid" 2>/dev/null; wait "$game_pid" 2>/dev/null; fi
    for pid in $wm_pids; do kill -CONT "$pid" 2>/dev/null; done
    if [ "$pillow_disabled" = yes ]; then
        lipc-set-prop com.lab126.pillow disableEnablePillow enable 2>/dev/null
    fi
    rm -f data/launch.lock/pid
    rmdir data/launch.lock 2>/dev/null
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
# Let KUAL finish closing before taking the screen.
sleep 1
if lipc-set-prop com.lab126.pillow disableEnablePillow disable 2>/dev/null; then pillow_disabled=yes; fi
for pid in $(pidof awesome 2>/dev/null); do
    # Never take ownership of an already-stopped process.
    case $(awk '{print $3}' "/proc/$pid/stat" 2>/dev/null) in T|t) ;; *)
        if kill -STOP "$pid" 2>/dev/null; then wm_pids="$wm_pids $pid"; fi ;;
    esac
done
./pokepal &
game_pid=$!
wait "$game_pid"
result=$?
game_pid=""
cleanup
if [ -f data/sleep-enabled ]; then
    nohup sh ./sleep-watch.sh >/dev/null 2>&1 &
else
    sleep_pid=$(cat data/sleep-watch.lock/pid 2>/dev/null)
    case "$sleep_pid" in
        ''|*[!0-9]*) ;;
        *) if [ -r "/proc/$sleep_pid/cmdline" ] && tr '\000' '\n' <"/proc/$sleep_pid/cmdline" | grep -Fxq './sleep-watch.sh'; then kill -TERM "$sleep_pid" 2>/dev/null; fi ;;
    esac
fi
if [ "$result" -eq 10 ]; then exit 0; fi
if [ "$result" -eq 0 ]; then lipc-set-prop com.lab126.appmgrd start app://com.lab126.booklet.home 2>/dev/null; fi
if [ "$result" -ne 0 ]; then eips 1 2 "PokePal could not start. Check extensions/pokepal/data/launch.log."; fi
exit "$result"

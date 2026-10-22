#!/bin/sh
# Optional power-event listener. It sleeps in read; there is no polling loop.
cd "$(dirname "$0")" || exit 1
[ -f data/sleep-enabled ] || exit 0
mkdir data/sleep-watch.lock 2>/dev/null || {
    old_pid=$(cat data/sleep-watch.lock/pid 2>/dev/null)
    case "$old_pid" in
        ''|*[!0-9]*) ;;
        *) if [ -r "/proc/$old_pid/cmdline" ] && tr '\000' '\n' <"/proc/$old_pid/cmdline" | grep -Fxq './sleep-watch.sh'; then exit 0; fi ;;
    esac
    rm -f data/sleep-watch.lock/pid data/sleep-watch.lock/events
    rmdir data/sleep-watch.lock 2>/dev/null || exit 1
    mkdir data/sleep-watch.lock || exit 1
}
echo "$$" > data/sleep-watch.lock/pid
listener=""
event_dir="/tmp/pokepal-sleep-$$"
cleanup() {
    trap - EXIT HUP INT TERM
    if [ -n "$listener" ]; then kill "$listener" 2>/dev/null;wait "$listener" 2>/dev/null;fi
    rm -f "$event_dir/events" data/sleep-watch.lock/pid
    rmdir "$event_dir" 2>/dev/null
    rmdir data/sleep-watch.lock 2>/dev/null
}
trap cleanup EXIT
trap 'exit 0' HUP INT TERM
umask 077
mkdir "$event_dir" || exit 1
mkfifo "$event_dir/events" || exit 1
lipc-wait-event -m com.lab126.powerd goingToScreenSaver,outOfScreenSaver >"$event_dir/events" &
listener=$!
while IFS= read -r event; do
    [ -f data/sleep-enabled ] || break
    # The open edition owns its own suspend/resume callbacks and save lock.
    case "$event" in
        *goingToScreenSaver*) ./pokepal --suspend >/dev/null 2>&1 ;;
        *outOfScreenSaver*) ./pokepal --resume >/dev/null 2>&1 ;;
    esac
done <"$event_dir/events"

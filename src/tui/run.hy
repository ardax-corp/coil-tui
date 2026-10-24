// The terminal loop: full screen, raw input, timers, redraws. Everything
// it drives lives in `tui::app`; this is the only module that needs a
// real terminal (`cli::term`, `cli::events`).
use io::{Stream, IoError, stdin, stdout};
use clock::mono_nanos;
use cli::ansi::enter_alt_screen;
use cli::ansi::leave_alt_screen;
use cli::ansi::hide_cursor;
use cli::ansi::show_cursor;
use cli::ansi::enable_mouse;
use cli::ansi::disable_mouse;
use cli::ansi::enable_paste;
use cli::ansi::disable_paste;
use cli::ansi::begin_sync;
use cli::ansi::end_sync;
use cli::color::color_level_from_env;
use cli::events::events;
use cli::term::raw_mode;
use cli::term::size_or;
use cli::term::put;
use cli::term::stdout_is_tty;
use tui::app::App;
use tui::app::app;
use tui::node::Node;

fn setup() -> string {
    return enter_alt_screen() + hide_cursor() + enable_mouse() + enable_paste();
}

fn teardown() -> string {
    return disable_paste() + disable_mouse() + show_cursor() + leave_alt_screen();
}

/// Run `root` full screen until something quits (`ctx.quit()`, Ctrl-C
/// by default) or input ends. The terminal is restored on the way out,
/// also after an error or a panic.
fn run(Node root) -> Result<(), IoError> {
    return run_app(app(root, color_level_from_env(stdout_is_tty())));
}

/// `run` for an `App` you set up yourself (theme, key bindings, timers).
fn run_app(App a) -> Result<(), IoError> {
    let out = stdout();
    let raw = raw_mode(stdin())?;
    put(out, setup())?;
    defer use (raw, out) {
        let _ = put(out, teardown());
        let _ = raw.leave();
    }
    let (cols, rows) = size_or(out, 80, 24);
    a.resize(cols, rows);
    let ev = events();
    let start = mono_nanos();
    while a.running {
        let now = (mono_nanos() - start) / 1000000;
        a.tick(now);
        let frame = a.draw();
        if frame != "" {
            put(out, begin_sync() + frame + end_sync())?;
        }
        if !a.running {
            break;
        }
        match ev.next(a.wait_ms(now))? {
            Option::Some(e) => {
                a.dispatch(e);
                for more in ev.poll()? {
                    a.dispatch(more);
                }
            },
            Option::None => {
                if ev.eof {
                    break;
                }
            },
        }
    }
    return;
}

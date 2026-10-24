# coil-tui

A component framework for terminal user interfaces in [Coil](https://github.com/ardax-corp/coil-lang), built on the `cli` package ([coil-cli](https://github.com/ardax-corp/coil-cli)). Package name: `tui`.

Build a screen out of components, lay them out in rows and columns, and
let the framework handle drawing, focus, keyboard and mouse input. Each
redraw paints a fresh frame and `cli::screen` writes only the cells that
changed.

```coil
use cell::Ref;
use tui::node::{Ctx, mount};
use tui::run::run;
use tui::widgets::layout::{column, row, block, spacer};
use tui::widgets::text::{text, text_fn};
use tui::widgets::input::{button, text_input};

fn main() {
    let name = text_input("Your name");
    let greeting = Ref::new("");
    let form = column([
        row([text("Name: ").fixed(6), mount(name).fill(1)]).fixed(1),
        button("Greet", fn (Ctx c) use (name, greeting) {
            greeting.set("Hello, " + name.value() + "!");
        }),
        text_fn(fn () use (greeting) => greeting.get()),
    ]);
    let root = column([block("Hello", form), spacer(), text("Tab moves, Enter presses, Ctrl-C quits")]);
    let _ = run(root);
}
```

This is [examples/hello.hy](examples/hello.hy); [examples/todo.hy](examples/todo.hy) is a bigger one (list, dialogs, key hints).

## Pieces

| Module | What |
|---|---|
| `tui::node` | `Component` trait, `mount`, `Node` (constraints, id, visibility), `Ctx` (focus, layers, timers, quit) |
| `tui::app` | `App`: layout and paint, event routing, focus, layers, timers, key bindings |
| `tui::run` | the terminal loop (alternate screen, raw mode, mouse, paste) |
| `tui::testing` | headless `Harness`: send keys, text, clicks and time; read the screen as text |
| `tui::layout`, `tui::geom`, `tui::canvas` | constraint solver, rects, clipped drawing |
| `tui::widgets::layout` | `row`, `column`, `flex`, `stack`, `block`, `pad`, `center`, `align`, `spacer` |
| `tui::widgets::text` | `text`, `styled`, `text_fn`, `rule` |
| `tui::widgets::input` | `Button`, `Checkbox`, `RadioGroup`, `TextInput` |
| `tui::widgets::list` | `List`, `Table` |
| `tui::widgets::scroll`, `tui::widgets::tabs` | `Scroll`, `Tabs` |
| `tui::widgets::status` | `Gauge`, `Spinner`, `KeyHints` |
| `tui::widgets::dialog` | `dialog`, `alert`, `confirm`, `menu` |

Writing your own component means implementing `render` (and whichever of
`measure`, `handle`, `focusable`, `children`, `arrange`, `constraint` it
needs) and calling `mount`. The design, and why things are the way they
are, is in [docs/design.md](docs/design.md).

## Testing a UI

```coil
let h = harness(root, 40, 10);
h.type_text("Ada");
h.keys("tab enter");
assert!(h.row(2) == "Hello, Ada!                             ");
```

## Development

`make test` runs the tests and `make fmt` checks formatting. Both expect
coil-stdlib and coil-cli checked out next to this repository, or their
`src` directories passed in `COIL_ROOTS`. `make examples` compiles the
examples.

## License

MIT — see [LICENSE](LICENSE).

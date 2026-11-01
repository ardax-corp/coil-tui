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

This is [examples/hello.coil](examples/hello.coil); [examples/todo.coil](examples/todo.coil) is a bigger one (list, dialogs, key hints). Run it from a checkout with coil-stdlib and coil-cli next to it (`run` reads the colour settings, hence `--allow-env`):

```bash
coil --allow-env --root ../coil-stdlib/src --root ../coil-cli/src --root src examples/hello.coil
```

## Use it

With [spool](https://github.com/ardax-corp/spool):

```bash
spool add tui --git https://github.com/ardax-corp/coil-tui.git --rev <commit SHA>
```

There are no tags yet, so pin a commit with `--rev`. spool also fetches the `cli` dependency. Without spool, clone this repo, [coil-cli](https://github.com/ardax-corp/coil-cli) and coil-stdlib next to your project and pass `--root ../coil-tui/src --root ../coil-cli/src --root ../coil-stdlib/src` to `coil`.

## Pieces

| Module | What |
|---|---|
| `tui::node` | `Component` trait, `mount`, `Node` (constraints, id, visibility), `Ctx` (focus, layers, timers, quit) |
| `tui::app` | `App`: layout and paint, event routing, focus, layers, timers, key bindings |
| `tui::run` | the terminal loop (alternate screen, raw mode, mouse, paste) |
| `tui::testing` | headless `Harness`: send keys, text, clicks and time; read the screen as text |
| `tui::layout`, `tui::geom`, `tui::canvas` | constraint solver, rects, clipped drawing |
| `tui::theme` | `Theme`, the named styles widgets draw with, and `default_theme` |
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

With `root` from the example above:

```coil
let h = harness(root, 40, 10);
h.type_text("Ada");
h.keys("tab enter");
assert!(h.row(3) == "│Hello, Ada!                           │");
```

## Development

`make test` runs the tests and the doc examples of the modules they
import, and `make fmt` checks formatting. Both expect coil-stdlib and
coil-cli checked out next to this repository, or their `src` directories
passed in `COIL_ROOTS`. `make examples` compiles the examples, and
`coil test --doc-tests-only src --root ../coil-stdlib/src --root ../coil-cli/src`
runs only the doc examples. Every public item has `///` docs; most
examples drive a UI through `tui::testing`.

## License

MIT — see [LICENSE](LICENSE).

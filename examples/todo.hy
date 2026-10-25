// A to-do list: a text input adds items, the list shows them, Space
// toggles done, d deletes (after asking), Tab moves between them.
//
//   coil --root <stdlib>/src --root <coil-cli>/src --root src examples/todo.hy
use cli::keys::{Event, describe_key};
use tui::node::Component;
use tui::node::Node;
use tui::node::Ctx;
use tui::node::mount;
use tui::canvas::Canvas;
use tui::layout::Constraint;
use tui::run::run;
use tui::widgets::layout::column;
use tui::widgets::layout::flex;
use tui::widgets::layout::block;
use tui::widgets::text::text_fn;
use tui::widgets::input::TextInput;
use tui::widgets::input::text_input;
use tui::widgets::list::List;
use tui::widgets::list::list;
use tui::widgets::status::key_hints;
use tui::widgets::dialog::confirm;

class Todo {
    pub items: Vec<string>,
    pub done: Vec<bool>,
    pub view: List,
}

impl Todo {
    pub fn add(string s) {
        self.items.push(s);
        self.done.push(false);
        self.refresh();
    }

    pub fn toggle(int i) {
        if i < self.done.len() {
            self.done[i] = !self.done[i];
            self.refresh();
        }
    }

    pub fn remove(int i) {
        let items: Vec<string> = Vec::new();
        let done: Vec<bool> = Vec::new();
        let k = 0;
        while k < self.items.len() {
            if k != i {
                items.push(self.items[k]);
                done.push(self.done[k]);
            }
            k++;
        }
        self.items = items;
        self.done = done;
        self.refresh();
    }

    pub fn refresh() {
        let rows: Vec<string> = Vec::new();
        let k = 0;
        while k < self.items.len() {
            let mark = "[ ] ";
            if self.done[k] {
                mark = "[x] ";
            }
            rows.push(mark + self.items[k]);
            k++;
        }
        self.view.items = rows;
    }

    pub fn left() -> int {
        let n = 0;
        for d in self.done {
            if !d {
                n++;
            }
        }
        return n;
    }
}

// The list plus the to-do keys (Space, d) on top of List's own.
class TodoList {
    pub todo: Todo,
    pub inner: Node,
    pub kids: Vec<Node>,
}

impl Component for TodoList {
    fn render(TodoList t, Canvas cv, Ctx ctx) {}

    fn children(TodoList t) -> Vec<Node> {
        return t.kids;
    }

    fn handle(TodoList t, Event e, Ctx ctx) -> bool {
        let spec = match e {
            Event::Key(k) => describe_key(k),
            default => "",
        };
        let i = t.todo.view.selected();
        if spec == "space" {
            t.todo.toggle(i);
            return true;
        }
        if spec == "d" && t.todo.items.len() > 0 {
            let todo = t.todo;
            confirm(
                ctx,
                "Delete",
                "Delete \"" + todo.items[i] + "\"?",
                fn (bool yes, Ctx c) use (todo, i) {
                    if yes {
                        todo.remove(i);
                    }
                },
            );
            return true;
        }
        return false;
    }
}

fn main() {
    let todo = new Todo(Vec::new(), Vec::new(), list(Vec::new()));
    todo.add("Write the coil-tui runner");
    todo.add("Try it in a real terminal");
    let input = text_input("What needs doing?").clearing();
    input
        .on_submit(
            fn (string s, Ctx c) use (todo) {
                if s != "" {
                    todo.add(s);
                }
            },
        );
    let lnode = mount(todo.view);
    let kids: Vec<Node> = Vec::new();
    kids.push(lnode);
    let tl = mount(new TodoList(todo, lnode, kids));
    let status = text_fn(fn () use (todo) => show(todo.left()) + " left");
    let hints = mount(
        key_hints().add("Tab", "switch").add("Space", "done").add("d", "delete").add("^C", "quit"),
    );
    let root = column(
        [
            block("New", mount(input).fixed(1)),
            block("To do", tl).fill(1),
            mount(flex(true).add(status).add(hints.fill(1)).spaced(3)).fixed(1),
        ],
    );
    let r = run(root);
}

use tests::assert;
use tui::canvas::Canvas;
use tui::canvas::Frame;
use tui::canvas::canvas;
use tui::canvas::frame;
use tui::geom::Align;
use tui::geom::rect;
use cli::screen::buffer;
use cli::screen::ascii_box;
use cli::style::plain;
use cli::style::fg;
use cli::style::red;

fn fresh(int w, int h) -> Canvas {
    return canvas(frame(buffer(w, h)));
}

test("sub canvases offset and clip") {
    let c = fresh(10, 3);
    let s = c.sub(rect(2, 1, 4, 1));
    let end = s.put(0, 0, "abcdefgh", plain());
    assert!(end == 8);
    assert!(c.frame.buf.text() == "          \n  abcd    \n          ");
    s.put(-2, 0, "xyz", plain());
    assert!(c.frame.buf.row_text(1) == "  zbcd    ");
    s.set(0, 1, "!", plain());
    assert!(c.frame.buf.row_text(2) == "          ");
}

test("nested sub canvases keep the outer clip") {
    let c = fresh(10, 1);
    let outer = c.sub(rect(1, 0, 3, 1));
    let inner = outer.sub(rect(1, 0, 10, 1));
    inner.put(0, 0, "hello", plain());
    assert!(c.frame.buf.row_text(0) == "  he      ");
    assert!(inner.w() == 10);
    assert!(inner.clip.w == 2);
}

test("wide characters cut by the clip become spaces") {
    let c = fresh(6, 1);
    let s = c.sub(rect(1, 0, 3, 1));
    s.put(0, 0, "日本", plain());
    assert!(c.frame.buf.row_text(0) == " 日   ");
    assert!(c.frame.buf.get(3, 0).text == " ");
    let t = fresh(4, 1);
    let u = t.sub(rect(1, 0, 3, 1));
    u.put(-1, 0, "日x", plain());
    assert!(t.frame.buf.row_text(0) == "  x ");
    assert!(t.frame.buf.get(0, 0).text == " ");
}

test("put_in aligns and truncates") {
    let c = fresh(10, 3);
    c.put_in(0, 0, 10, "ab", plain(), Align::Center);
    c.put_in(0, 1, 10, "ab", plain(), Align::End);
    c.put_in(0, 2, 5, "abcdefg", plain(), Align::Start);
    assert!(c.frame.buf.text() == "    ab    \n        ab\nabcd…     ");
}

test("fill, paint and boxes") {
    let c = fresh(4, 3);
    c.draw_box(0, 0, 4, 3, ascii_box(), plain());
    assert!(c.frame.buf.text() == "+--+\n|  |\n+--+");
    c.paint(0, 0, 2, 1, fg(red()));
    assert!(c.get(0, 0).text == "+");
    assert!(c.get(0, 0).style.eq(fg(red())));
    assert!(c.get(2, 0).style.eq(plain()));
    let s = c.sub(rect(1, 1, 2, 1));
    s.clear(plain());
    s.fill(0, 0, 5, 5, "#", plain());
    assert!(c.frame.buf.text() == "+--+\n|##|\n+--+");
}

test("cursor requests are clipped and absolute") {
    let c = fresh(10, 5);
    let s = c.sub(rect(3, 2, 4, 2));
    s.cursor(9, 9);
    assert!(!c.frame.has_cursor);
    s.cursor(1, 1);
    assert!(c.frame.has_cursor);
    assert!(c.frame.cursor_x == 4);
    assert!(c.frame.cursor_y == 3);
}

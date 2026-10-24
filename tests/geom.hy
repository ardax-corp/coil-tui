use tests::assert;
use tui::geom::{Rect, Align, rect, size, clamp};

test("rect edges and containment") {
    let r = rect(2, 3, 4, 5);
    assert!(r.right() == 6);
    assert!(r.bottom() == 8);
    assert!(r.contains(2, 3));
    assert!(r.contains(5, 7));
    assert!(!r.contains(6, 7));
    assert!(!r.contains(1, 3));
    assert!(rect(0, 0, -3, 2).w == 0);
    assert!(rect(0, 0, 0, 2).is_empty());
    assert!(size(-1, 4).w == 0);
}

test("intersect") {
    let a = rect(0, 0, 10, 10);
    let b = rect(5, 6, 10, 10);
    assert!(a.intersect(b).eq(rect(5, 6, 5, 4)));
    assert!(b.intersect(a).eq(rect(5, 6, 5, 4)));
    assert!(a.intersect(rect(20, 20, 2, 2)).is_empty());
}

test("inset, shrink, offset, local") {
    let r = rect(1, 1, 10, 6);
    assert!(r.inset(1, 2, 3, 4).eq(rect(5, 2, 4, 2)));
    assert!(r.shrink(1).eq(rect(2, 2, 8, 4)));
    assert!(r.shrink(5).eq(rect(6, 6, 0, 0)));
    assert!(r.offset(-1, 2).eq(rect(0, 3, 10, 6)));
    assert!(r.local().eq(rect(0, 0, 10, 6)));
}

test("place aligns and clips") {
    let r = rect(10, 0, 10, 5);
    assert!(r.place(4, 1, Align::Start, Align::Start).eq(rect(10, 0, 4, 1)));
    assert!(r.place(4, 1, Align::Center, Align::Center).eq(rect(13, 2, 4, 1)));
    assert!(r.place(4, 1, Align::End, Align::End).eq(rect(16, 4, 4, 1)));
    assert!(r.place(4, 1, Align::Stretch, Align::Start).eq(rect(10, 0, 10, 1)));
    assert!(r.place(40, 9, Align::Center, Align::Center).eq(r));
    assert!(clamp(5, 0, 3) == 3);
    assert!(clamp(-5, 0, 3) == 0);
}

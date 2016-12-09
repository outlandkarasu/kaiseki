/**
 *  Kaiseki source context classes.
 */
module kaiseki.context;

import std.algorithm : each;
import std.range : isForwardRange, ElementType;
import std.array : front, empty, popFront, save;
import std.container : Array;
import std.string : format;

/**
 *  Params:
 *      R = source range.
 */
class Context(R) {
    alias Range = R;
    alias Character = ElementType!Range;

    static assert(isForwardRange!Range);

    /// parsing event
    struct Event {
        enum Type {Start, End}
        Type type;
        size_t position;
        Range range;
        EventHandler handler;

        void doEvent() const {
            if(handler !is null) {
                handler(this);
            }
        }
    }

    /// event handler
    alias EventHandler = void delegate(ref const(Event) e);

    this(R range) {
        this.range_ = range;
    }

    @property const {
        Character front() {return range_.front;}
        bool empty() {return range_.empty;}
        size_t position() {return position_;}
    }

    void popFront() {
        range_.popFront();
        ++position_;
    }

    void start(EventHandler handler = null) {
        auto r = range_.save;
        states_ ~= State(position_, r, events_.length, handler);
        events_ ~= Event(Event.Type.Start, position_, r, handler);
    }

    void accept()
    in {
        assert(!states_.empty);
    } body {
        // add an accept event
        immutable s = states_.back;
        events_ ~= Event(Event.Type.End, position_, range_.save, s.handler);

        // if only have a last state, call event handler
        if(states_.length == 1) {
            // reset events state if handler throw exceptions.
            scope(failure) events_.removeBack(); 
            foreach(e; events_) {
                e.doEvent();
            }
            events_.clear();
        }

        states_.removeBack();
    }

    void reject()
    in {
        assert(!states_.empty);
    } body {
        immutable s = states_.back;
        states_.removeBack();

        // reset to a before state
        range_ = s.range;
        position_ = s.position;
        events_.length = s.eventLength;
    }

private:
    struct State {
        size_t position;
        Range range;
        size_t eventLength;
        EventHandler handler;
    }

    Range range_;
    size_t position_;
    Array!State states_;
    Array!Event events_;
    EventHandler handler_;
}

auto context(R)(R range) {return new Context!R(range);}

///
unittest {
    auto c = context("test");
    assert(c.front == 't');
    assert(c.position == 0);
    assert(!c.empty);

    c.popFront();
    assert(c.front == 'e');
    assert(c.position == 1);
    assert(!c.empty);

    c.popFront();
    assert(c.front == 's');
    assert(c.position == 2);
    assert(!c.empty);

    c.popFront();
    assert(c.front == 't');
    assert(c.position == 3);
    assert(!c.empty);

    c.popFront();
    assert(c.position == 4);
    assert(c.empty);
}

///
unittest {
    string[] accepted;
    auto c = context("test");

    typeof(c).EventHandler makeHandler(string tag) {
        typeof(return) handler = (ref e) {
            accepted ~= format("%s %s %d %s", tag, e.type, e.position, e.range);
        };
        return handler;
    }

    assert(c.front == 't');
    assert(c.position == 0);

    // state 1
    c.start(makeHandler("1"));
    c.popFront();

    // state 2
    c.start(makeHandler("2"));
    c.popFront();

    // state 3
    c.start(makeHandler("3"));
    c.popFront();
    assert(c.front == 't');
    assert(c.position == 3);

    // reject state 3
    c.reject();
    assert(c.front == 's');
    assert(c.position == 2);

    // continue state 2
    c.popFront();

    // accept state 2
    c.accept();

    // continue state 1
    c.popFront();
    assert(c.empty);

    // accept state 1
    c.accept();

    assert(accepted[0] == "1 Start 0 test", accepted[0]);
    assert(accepted[1] == "2 Start 1 est", accepted[1]);
    assert(accepted[2] == "2 End 3 t", accepted[2]);
    assert(accepted[3] == "1 End 4 ", accepted[3]);
}


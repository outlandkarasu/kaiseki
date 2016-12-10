/**
 *  Kaiseki source context classes.
 */
module kaiseki.context;

import std.algorithm : each;
import std.range : isInputRange, ElementType;
import std.array : front, empty, popFront, save;
import std.container : Array;
import std.string : format;

import kaiseki.buffer : InputRangeBuffer;

/**
 *  Params:
 *      R = source range.
 */
class Context(R) {
    static assert(isInputRange!R);

    alias Range = R;
    alias Character = ElementType!Range;
    alias EventHandler = void delegate(const(Character[]) r);

    this(R range) {
        this.buffer_ = InputRangeBuffer!Range(range);
    }

    @property const {
        Character front() {return buffer_.front;}
        bool empty() {return buffer_.empty;}
        size_t position() {return buffer_.position;}
    }

    void popFront() {buffer_.popFront();}

    void start(EventHandler handler = null) {
        immutable pos = buffer_.position;
        immutable epos = events_.length;

        if(handler is null) {
            states_ ~= State(pos, epos, false);
        } else {
            states_ ~= State(pos, epos, true);
            events_ ~= Event(handler, pos);
        }
    }

    void accept()
    in {
        assert(!states_.empty);
    } body {
        // add an accept event
        immutable s = states_.back;
        if(s.hasEvent) {
            events_[s.eventPosition].end = buffer_.position;
        }

        // if only have a last state, call event handler
        if(states_.length == 1) {
            events_.each!(e => e.handler(buffer_[e.start .. e.end]));
            events_.clear();
            buffer_.clear();
        }

        states_.removeBack();
    }

    void reject()
    in {
        assert(!states_.empty);
    } body {
        immutable s = states_.back;
        states_.removeBack();
        buffer_.position = s.position;
        events_.length = s.eventPosition;
    }

private:
    struct Event {
        EventHandler handler;
        size_t start;
        size_t end;
    }

    struct State {
        size_t position;
        size_t eventPosition;
        bool hasEvent;
    }

    InputRangeBuffer!Range buffer_;
    Array!State states_;
    Array!Event events_;
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
        typeof(return) handler = (const(dchar[]) match) {
            accepted ~= format("%s %s", tag, match);
        };
        return handler;
    }

    assert(c.front == 't');
    assert(c.position == 0);

    // state 1
    c.start(makeHandler("1"));
    c.popFront();
    assert(c.front == 'e');
    assert(c.position == 1);

    // state 2
    c.start(makeHandler("2"));
    c.popFront();
    assert(c.front == 's');
    assert(c.position == 2);

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

    assert(accepted.length == 2);
    assert(accepted[0] == "1 test", accepted[0]);
    assert(accepted[1] == "2 es", accepted[1]);
}


/**
 *  source buffer classes.
 */
module kaiseki.buffer;

import std.algorithm : copy;
import std.array : Appender, front, empty, popFront;
import std.range : isInputRange, ElementType;
import std.traits : Unqual;

/// back trackable range buffer
struct InputRangeBuffer(R) {
    static assert(isInputRange!R);

    alias OriginalRange = R;
    alias Element = Unqual!(ElementType!R);

    this(R r) {
        this.range_ = r;
        if(!r.empty) {
            buffer_ ~= r.front;
        }
    }

    @property const {
        const(Element) front()
        in {
            assert(!empty);
        } body {
            return data.front;
        }

        bool empty() {return data.empty;}

        @safe pure nothrow @nogc {
            size_t position() {return position_;}
            size_t bufferStart() {return bufferStart_;}
        }
    }
    
    @property @safe nothrow @nogc void position(size_t pos)
    in {
        assert(bufferStart_ <= pos && pos <= position_);
    } body {
        position_ = pos;
    }

    void popFront()
    in {
        assert(!empty);
    } body {
        if(data.length <= 1 && !range_.empty) {
            range_.popFront();
            if(!range_.empty) {
                buffer_ ~= range_.front;
            }
        }
        ++position_;
    }

    void clear() {
        auto rest = data;
        rest.copy(buffer_.data);
        buffer_.shrinkTo(rest.length);
        bufferStart_ = position_;
    }

    const(Element)[] opSlice(size_t start, size_t end) const
    in {
        assert(bufferStart_ <= start && start <= end);
        assert(end <= (empty ? position : position + 1));
    } body {
        return buffer_.data[start - bufferStart_ .. end - bufferStart_];
    }

private:
    @property inout(Element)[] data() inout {
        return buffer_.data[position_ - bufferStart_ .. $];
    }

    Appender!(Element[]) buffer_;
    OriginalRange range_;
    size_t position_;
    size_t bufferStart_;
}

auto buffer(R)(R r) {return InputRangeBuffer!R(r);}

///
unittest {
    auto b = buffer("test");
    assert(b[0 .. 1] == "t");
    assert(b.front == 't');
    assert(!b.empty);
    assert(b.position == 0);
    assert(b.bufferStart == 0);

    b.popFront();
    assert(b[0 .. 2] == "te");
    assert(b.front == 'e');
    assert(!b.empty);
    assert(b.position == 1);
    assert(b.bufferStart == 0);

    b.popFront();
    assert(b[0 .. 3] == "tes");
    assert(b.front == 's');
    assert(!b.empty);
    assert(b.position == 2);
    assert(b.bufferStart == 0);

    b.position = 1;
    assert(b[0 .. 2] == "te");
    assert(b.front == 'e');
    assert(!b.empty);
    assert(b.position == 1);
    assert(b.bufferStart == 0);

    b.popFront();
    assert(b[0 .. 3] == "tes");
    assert(b.front == 's');
    assert(!b.empty);
    assert(b.position == 2);
    assert(b.bufferStart == 0);

    b.clear();
    assert(b[2 .. 3] == "s");
    assert(b.front == 's');
    assert(!b.empty);
    assert(b.position == 2);
    assert(b.bufferStart == 2);

    b.popFront();
    assert(b[2 .. 4] == "st");
    assert(b.front == 't');
    assert(!b.empty);
    assert(b.position == 3);
    assert(b.bufferStart == 2);

    b.popFront();
    assert(b[2 .. 4] == "st");
    assert(b.empty);
    assert(b.position == 4);
    assert(b.bufferStart == 2);

    b.clear();
    assert(b[4 .. 4].empty);
    assert(b.empty);
    assert(b.position == 4);
    assert(b.bufferStart == 4);
}

unittest {
    immutable(ubyte)[] bytes = [0, 1, 2, 3];
    auto b = buffer(bytes);
    assert(b.front == 0);
}

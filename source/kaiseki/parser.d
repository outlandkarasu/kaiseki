/**
 *  Kaiseki parser classes.
 */
module kaiseki.parser;

import kaiseki.context;

/// match an any char.
bool parseAny(R)(Context!R context) {
    if(!context.empty) {
        context.popFront();
        return true;
    }
    return false;
}

///
unittest {
    assert(context("a").parseAny);
    assert(!context("").parseAny);

    auto c = context("test");
    assert(c.parseAny);
    assert(c.position == 1);
}

/// match empty context
bool parseEmpty(R)(Context!R context) {
    return context.empty;
}

///
unittest {
    assert(!context("a").parseEmpty);
    assert(context("").parseEmpty);

    auto c = context("t");
    assert(!c.parseEmpty);
    assert(c.position == 0);

    c.popFront();
    assert(c.empty);
    assert(c.parseEmpty);
}

/// parse a character.
bool parseChar(alias C, R)(Context!R context) {
    if(!context.empty && context.front == C) {
        context.popFront();
        return true;
    }
    return false;
}

///
unittest {
    assert(context("a").parseChar!'a');
    assert(!context("a").parseChar!'b');

    auto c = context("t");
    assert(!c.parseChar!'a');
    assert(c.position == 0);
    assert(c.parseChar!'t');
    assert(c.position == 1);
}

/// parse string
bool parseString(alias S, R)(Context!R context) {
    context.start();
    foreach(c; S) {
        if(context.empty || context.front != c) {
            context.reject();
            return false;
        }
        context.popFront();
    }

    context.accept();
    return true;
}

///
unittest {
    assert(context("test").parseString!"test");
    assert(!context("etst").parseString!"test");

    auto c = context("test");
    assert(c.parseString!"te");
    assert(c.position == 2);

    assert(!c.parseString!"ss");
    assert(c.position == 2);

    assert(c.parseString!"st");
    assert(c.position == 4);
}


/**
 *  Kaiseki parser classes.
 */
module kaiseki.parser;

import kaiseki.context : Context, context;

/// match any state.
bool parseTrue(R)(Context!R context) {
    return true;
}

///
unittest {
    assert(context("a").parseTrue);
    assert(context("").parseTrue);

    auto c = context("test");
    assert(c.parseTrue);
    assert(c.position == 0);
}


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
template parseChar(alias C) {
    bool parseChar(R)(Context!R context) {
        if(!context.empty && context.front == C) {
            context.popFront();
            return true;
        }
        return false;
    }
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
template parseString(alias S) {
    bool parseString(R)(Context!R context) {
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

/// parse character set
template parseSet(alias S) {
    bool parseSet(R)(Context!R context) {
        if(!context.empty) {
            auto front = context.front;
            foreach(c; S) {
                if(c == front) {
                    context.popFront();
                    return true;
                }
            }
        }
        return false;
    }
}

///
unittest {
    assert(context("test").parseSet!"stuv");
    assert(context("sest").parseSet!"stuv");
    assert(!context("eest").parseSet!"stuv");

    auto c = context("test");
    assert(c.parseSet!"vut");
    assert(c.position == 1);
    assert(!c.parseSet!"vut");
    assert(c.position == 1);
}

/// parse character range
template parseRange(alias C1, alias C2) {
    bool parseRange(R)(Context!R context) {
        if(!context.empty) {
            auto front = context.front;
            if(C1 <= front && front <= C2) {
                context.popFront();
                return true;
            }
        }
        return false;
    }
}

///
unittest {
    assert(context("test").parseRange!('a', 'z'));
    assert(!context("test").parseRange!('0', '9'));

    auto c = context("test");
    assert(c.parseRange!('a', 'z'));
    assert(c.position == 1);
    assert(!c.parseRange!('0', '9'));
    assert(c.position == 1);
}

/// test parser
template testAnd(alias P) {
    bool testAnd(R)(Context!R context) {
        context.start();
        scope(exit) context.reject();
        return P(context);
    }
}

///
unittest {
    auto c = context("test");
    assert(c.testAnd!(parseChar!('t')));
    assert(c.position == 0);
    assert(!c.testAnd!(parseChar!('s')));
    assert(c.position == 0);
}

/// test not parser
template testNot(alias P) {
    bool testNot(R)(Context!R context) {
        context.start();
        scope(exit) context.reject();
        return !P(context);
    }
}

///
unittest {
    auto c = context("test");
    assert(!c.testNot!(parseChar!('t')));
    assert(c.position == 0);
    assert(c.testNot!(parseChar!('s')));
    assert(c.position == 0);
}

/// zero or one parser
template zeroOrOne(alias P) {
    bool zeroOrOne(R)(Context!R context) {
        P(context);
        return true;
    }
}

///
unittest {
    auto c = context("tttest");
    assert(c.zeroOrOne!(parseChar!('t')));
    assert(c.position == 1);
    assert(c.zeroOrOne!(parseChar!('e')));
    assert(c.position == 1);
}

/// zero or more parser
template zeroOrMore(alias P) {
    bool zeroOrMore(R)(Context!R context) {
        while(P(context)) {
            // do nothing
        }
        return true;
    }
}

///
unittest {
    auto c = context("tttest");
    assert(c.zeroOrMore!(parseChar!('t')));
    assert(c.position == 3);
    assert(c.zeroOrMore!(parseChar!('t')));
    assert(c.position == 3);
}

/// one or more parser
template oneOrMore(alias P) {
    bool oneOrMore(R)(Context!R context) {
        bool result = false;
        while(P(context)) {
            result = true;
        }
        return result;
    }
}

///
unittest {
    auto c = context("tttest");
    assert(c.oneOrMore!(parseChar!('t')));
    assert(c.position == 3);
    assert(!c.oneOrMore!(parseChar!('t')));
    assert(c.position == 3);
}

/// sequence parser
template sequence(P...) {
    bool sequence(R)(Context!R context) {
        context.start();
        foreach(p; P) {
            if(!p(context)) {
                context.reject();
                return false;
            }
        }

        context.accept();
        return true;
    }
}

///
unittest {
    auto c = context("test");
    assert(c.sequence!(parseChar!'t', parseChar!'e'));
    assert(c.position == 2);
    assert(!c.sequence!(parseChar!'s', parseChar!'e'));
    assert(c.position == 2);
}

/// choice parser
template choice(P...) {
    bool choice(R)(Context!R context) {
        foreach(p; P) {
            if(p(context)) {
                return true;
            }
        }
        return false;
    }
}

///
unittest {
    auto c = context("test");
    assert(c.choice!(parseChar!'t', parseChar!'e'));
    assert(c.position == 1);
    assert(!c.choice!(parseChar!'s', parseChar!'t'));
    assert(c.position == 1);
}

/// action parser
template action(alias P, alias A) {
    bool action(R)(Context!R context) {
        context.start(A);
        if(P(context)) {
            context.accept();
            return true;
        }
        context.reject();
        return false;
    }
}

///
unittest {
    const(dchar)[] buffer;
    auto handler = (const(dchar)[] match) {buffer ~= match.dup;};

    alias parse = choice!(
        action!(parseString!"testa", handler),
        sequence!(
            action!(parseString!"tes", handler), // match once but not call handler.
            action!(parseString!"ta", handler),
            ),
        action!(parseString!"test", handler),
    );

    auto c = context("test");
    assert(parse(c));
    assert(c.empty);
    assert(c.position == 4);
    assert(buffer == "test");
}


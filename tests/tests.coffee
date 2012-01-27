callbackGroup = () ->
	group = {}
	group.reset = () ->
		for key, value of group
			value.reset() if Object::toString.call(value.reset) is "[object Function]"
	return group

module "Finch",
	teardown: ->
		Finch.reset()

test "Trivial routing", sinon.test ->

	Finch.route "foo/bar", foo_bar = @stub()
	Finch.route "baz/quux", baz_quux = @stub()

	# Test routes

	Finch.call "/foo/bar"

	ok foo_bar.called, "foo/bar called"

	Finch.call "/baz/quux"

	ok baz_quux.called, "baz/quux called"

test "Simple hierarchical routing", sinon.test ->

	Finch.route "foo",          	foo = @stub()
	Finch.route "[foo]/bar",    	foo_bar = @stub()
	Finch.route "[foo/bar]/:id",	foo_bar_id = @stub()
	Finch.route "[foo]/baz",    	foo_baz = @stub()
	Finch.route "[foo/baz]/:id",	foo_baz_id = @stub()
	Finch.route "quux",         	quux = @stub()
	Finch.route "[quux]/:id",   	quux_id = @stub()

	# Test routes

	Finch.call "/foo/bar"

	equal foo.callCount, 1, "foo called once"
	deepEqual foo.getCall(0).args, [{}], "foo called with correct params"
	equal foo_bar.callCount, 1, "foo/bar called once"
	deepEqual foo_bar.getCall(0).args, [{}], "foo called with correct params"
	ok foo.calledBefore(foo_bar), "foo called before foo/bar"
	foo.reset()
	foo_bar.reset()

	Finch.call "/foo/bar/123"

	ok !foo.called, "foo not called again"
	ok !foo_bar.called, "foo/bar not called again"
	equal foo_bar_id.callCount, 1, "foo/bar/id called once"
	deepEqual foo_bar_id.getCall(0).args, [{ id: "123" }], "foo/bar/id params"
	foo_bar_id.reset()

	Finch.call "/foo/bar/123"

	ok !foo.called, "foo not called again"
	ok !foo_bar.called, "foo/bar not called again"
	ok !foo_bar_id.called, "foo/bar/id not called again"

	Finch.call "/foo/bar/123?x=Hello&y=World"

	ok !foo.called, "foo not called again"
	ok !foo_bar.called, "foo/bar not called again"
	ok !foo_bar_id.called, "foo/bar/id not called again"

	Finch.call "/foo/baz/456"

	ok !foo.called, "foo not called again"
	ok foo_baz.called, "foo/baz called"
	ok foo_baz_id.called, "foo/baz/id called"
	ok foo_baz.calledBefore(foo_baz_id), "foo/baz called before foo/baz/id"
	deepEqual foo_baz_id.getCall(0).args, [{ id: "456" }], "foo/baz/id params"
	foo_baz.reset()
	foo_baz_id.reset()

	Finch.call "/quux/789?band=Sunn O)))&genre=Post-Progressive Fridgecore"

	ok quux.called, "quux called"
	ok quux_id.called, "quux/id called"
	ok quux.calledBefore(quux_id), "quux called before quux/id"
	deepEqual quux_id.getCall(0).args, [{ id: "789" }], "quux/id params"

test "More hierarchical routing", sinon.test ->

	Finch.route "foo",           	foo = @stub()
	Finch.route "[foo]/bar/baz", 	foo_bar_baz = @stub()
	Finch.route "foo/bar",       	foo_bar = @stub()
	Finch.route "[foo/bar]/quux",	foo_bar_quux = @stub()

	# Test routes

	Finch.call "/foo/bar/baz"

	ok foo.called, "foo called"
	ok foo_bar_baz.called, "foo/bar/baz called"
	ok foo.calledBefore(foo_bar_baz), "foo called before foo/bar/baz"
	ok !foo_bar.called, "foo/bar NOT called"
	foo.reset()
	foo_bar_baz.reset()

	Finch.call "/foo/bar/quux"
	ok foo_bar.called, "foo/bar called"
	ok foo_bar_quux.called, "foo/bar/quux called"
	ok foo_bar.calledBefore(foo_bar_quux), "foo/bar called before foo/bar/quux"
	ok !foo.called, "foo NOT called"

test "Empty string params", sinon.test ->

	Finch.route "quux",      	quux = @stub()
	Finch.route "[quux]/:id",	quux_id = @stub()

	# Test routes

	Finch.call "/quux/123?x=&y="

	ok quux.called, "quux called"
	ok quux_id.called, "quux/id called"
	ok quux.calledBefore(quux_id), "quux called before quux/id"
	deepEqual quux_id.getCall(0).args[0], {
		id: "123"
	}, "quux params"

test "Collision between inlined and query string params", sinon.test ->

	Finch.route "foo/:bar/:baz", foo_bar_baz = @stub()

	# Test routes

	Finch.call "/foo/abc/def?bar=123&baz=456&quux=789"

	ok foo_bar_baz.called, "foo/bar/baz called"
	deepEqual foo_bar_baz.getCall(0).args[0], {
		bar: "abc"
		baz: "def"
	}, "foo/bar/baz params"

test "Simple routing with setup/teardown", sinon.test ->

	cb = callbackGroup()

	Finch.route "/",
		setup:   	cb.setup_slash = @stub()
		teardown:	cb.teardown_slash = @stub()
	Finch.route "/foo",
		setup:   	cb.setup_foo = @stub()
		teardown:	cb.teardown_foo = @stub()
	Finch.route "foo/bar",
		setup:   	cb.setup_foo_bar = @stub()
		teardown:	cb.teardown_foo_bar = @stub()

	# Test routes

	Finch.call "/"

	equal cb.setup_slash.callCount, 1,   	'/: / setup called once'
	equal cb.teardown_slash.callCount, 0,	'/: / teardown not called'
	cb.reset()

	Finch.call "/foo"

	equal cb.setup_slash.callCount, 0,   	'/foo: / setup not called'
	equal cb.teardown_slash.callCount, 1,	'/foo: / teardown called once'
	equal cb.setup_foo.callCount, 1,     	'/foo: foo setup called once'
	equal cb.teardown_foo.callCount, 0,  	'/foo: foo teardown not called'
	cb.reset()

	Finch.call "/foo/bar"

	equal cb.setup_slash.callCount, 0,     	'/foo/bar: / setup not called'
	equal cb.teardown_slash.callCount, 0,  	'/foo/bar: / teardown not called'
	equal cb.setup_foo.callCount, 0,       	'/foo/bar: foo setup not called'
	equal cb.teardown_foo.callCount, 1,    	'/foo/bar: foo teardown called once'
	equal cb.setup_foo_bar.callCount, 1,   	'/foo/bar: foo/bar setup called once'
	equal cb.teardown_foo_bar.callCount, 0,	'/foo/bar: foo/bar teardown not called'
	cb.reset()

	Finch.call "/foo/bar?baz=quux"

	equal cb.setup_slash.callCount, 0,     	'/foo/bar?baz=quux: / setup not called'
	equal cb.teardown_slash.callCount, 0,  	'/foo/bar?baz=quux: / teardown not called'
	equal cb.setup_foo.callCount, 0,       	'/foo/bar?baz=quux: foo setup not called'
	equal cb.teardown_foo.callCount, 0,    	'/foo/bar?baz=quux: foo teardown not called'
	equal cb.setup_foo_bar.callCount, 0,   	'/foo/bar?baz=quux: foo/bar setup not called'
	equal cb.teardown_foo_bar.callCount, 0,	'/foo/bar?baz=quux: foo/bar teardown not called'
	cb.reset()

	Finch.call "/foo/bar?baz=xyzzy"

	equal cb.setup_slash.callCount, 0,     	'/foo/bar?baz=xyzzy: / setup not called'
	equal cb.teardown_slash.callCount, 0,  	'/foo/bar?baz=xyzzy: / teardown not called'
	equal cb.setup_foo.callCount, 0,       	'/foo/bar?baz=xyzzy: foo setup not called'
	equal cb.teardown_foo.callCount, 0,    	'/foo/bar?baz=xyzzy: foo teardown not called'
	equal cb.setup_foo_bar.callCount, 0,   	'/foo/bar?baz=xyzzy: foo/bar setup not called'
	equal cb.teardown_foo_bar.callCount, 0,	'/foo/bar?baz=xyzzy: foo/bar teardown not called'
	cb.reset()

test "Hierarchical routing with setup/teardown", sinon.test ->

	cb = callbackGroup()

	Finch.route "foo",
		setup:   	cb.setup_foo = @stub()
		teardown:	cb.teardown_foo = @stub()
	Finch.route "[foo]/bar",
		setup:   	cb.setup_foo_bar = @stub()
		teardown:	cb.teardown_foo_bar = @stub()
	Finch.route "[foo/bar]/:id",
		setup:   	cb.setup_foo_bar_id = @stub()
		teardown:	cb.teardown_foo_bar_id = @stub()
	Finch.route "[foo]/baz",
		setup:   	cb.setup_foo_baz = @stub()
		teardown:	cb.teardown_foo_baz = @stub()
	Finch.route "[foo/baz]/:id",
		setup:   	cb.setup_foo_baz_id = @stub()
		teardown:	cb.teardown_foo_baz_id = @stub()

	# Test routes

	Finch.call "/foo"

	ok cb.setup_foo.called,	"/foo: foo setup"
	cb.reset()

	Finch.call "/foo/bar"

	ok !cb.setup_foo.called,   	"/foo/bar: no foo setup"
	ok !cb.teardown_foo.called,	"/foo/bar: no foo teardown"
	ok cb.setup_foo_bar.called,	"/foo/bar: foo/bar setup"
	cb.reset()

	Finch.call "/foo"

	ok cb.teardown_foo_bar.called,	"/foo return: foo/bar teardown"
	ok !cb.setup_foo.called,      	"/foo return: no foo setup"
	cb.reset()

	Finch.call "/foo/bar/123?x=abc"
	ok !cb.teardown_foo.called,   	"/foo/bar/123: no foo teardown"
	ok !cb.setup_foo.called,      	"/foo/bar/123: no foo setup"
	ok cb.setup_foo_bar.called,   	"/foo/bar/123: foo/bar setup"
	ok cb.setup_foo_bar_id.called,	"/foo/bar/123: foo/bar/id setup"
	cb.reset()

	Finch.call "/foo/bar/456?x=aaa&y=zzz"

	ok cb.teardown_foo_bar_id.called,	"/foo/bar/456?x=aaa&y=zzz: foo/bar/id teardown"
	ok cb.setup_foo_bar_id.called,   	"/foo/bar/456?x=aaa&y=zzz: foo/bar/id setup"
	cb.reset()

	Finch.call "/foo/bar/456?x=bbb&y=zzz"

	ok !cb.setup_foo_bar_id.called,	"/foo/bar/456?x=bbb&y=zzz: no foo/bar/id setup"
	cb.reset()

	Finch.call "/foo/bar/456?y=zzz&x=bbb"

	ok !cb.setup_foo_bar_id.called,	"/foo/bar/456?y=zzz&x=bbb: no foo/bar/id setup"
	cb.reset()

	Finch.call "/foo/baz/789"

	ok cb.teardown_foo_bar_id.called, 	"/foo/baz/789: foo/baz/id teardown"
	ok cb.teardown_foo_bar.called,    	"/foo/baz/789: foo/bar teardown"
	ok !cb.teardown_foo.called,       	"/foo/baz/789: no foo teardown"
	ok !cb.setup_foo.called,          	"/foo/baz/789: no foo setup"
	ok cb.setup_foo_baz.calledOnce,   	"/foo/baz/789: foo/baz setup"
	ok cb.setup_foo_baz_id.calledOnce,	"/foo/baz/789: foo/baz/id setup"
	cb.reset()

	Finch.call "/foo/baz/abc?term=Hello"

	ok cb.teardown_foo_baz_id.called,	"/foo/baz/abc?term=Hello: foo/baz/id teardown"
	ok cb.setup_foo_baz_id.called,   	"/foo/baz/abc?term=Hello: foo/baz/id setup"
	cb.reset()

	Finch.call "/foo/baz/abc?term=World"

	ok !cb.teardown_foo_baz_id.called,	"/foo/baz/abc?term=World: no foo/baz/id teardown"
	ok !cb.setup_foo_baz_id.called,   	"/foo/baz/abc?term=World: no foo/baz/id setup"

test "Calling with context", sinon.test ->

	Finch.route "foo",
		setup:   	setup_foo = @stub()
		teardown:	teardown_foo = @stub()
	Finch.route "bar", @stub()

	# Test routes

	Finch.call "/foo"

	equal setup_foo.callCount, 1, 'foo setup called once'
	context = setup_foo.getCall(0).thisValue

	Finch.call "/bar"
	ok teardown_foo.calledOn(context), 'foo teardown called on same context as setup'

test "Hierarchical calling with context", sinon.test ->

	Finch.route "foo",
		setup:   	setup_foo = @stub()
		teardown:	teardown_foo = @stub()
	Finch.route "[foo]/bar",
		setup:   	setup_foo_bar = @stub()
		teardown:	teardown_foo_bar = @stub()
	Finch.route "baz", @stub()

	# Test routes

	Finch.call "/foo"

	equal setup_foo.callCount, 1, 'foo setup called once'
	foo_context = setup_foo.getCall(0).thisValue

	Finch.call "/foo/bar"

	equal setup_foo_bar.callCount, 1, 'foo/bar setup called once'
	foo_bar_context = setup_foo_bar.getCall(0).thisValue

	notEqual foo_context, foo_bar_context, 'foo/bar should be called on a different context than foo'

	Finch.call "/baz"

	equal teardown_foo_bar.callCount, 1, 'foo/bar teardown called once'
	equal teardown_foo.callCount, 1, 'foo teardown called once'
	ok teardown_foo_bar.calledBefore(teardown_foo), 'foo/bar teardown called before foo teardown'

	ok teardown_foo_bar.calledOn(foo_bar_context), 'foo/bar teardown called on same context as setup'
	ok teardown_foo.calledOn(foo_context), 'foo teardown called on same context as'

test "Route sanitation", sinon.test ->

	Finch.route "/", slash_stub = @stub()
	Finch.route "/foo", foo_stub = @stub()
	Finch.route "/foo/bar", foo_bar_stub = @stub()

	Finch.call ""
	equal slash_stub.callCount, 1, "/ called once"
	slash_stub.reset()

	Finch.call "/"
	equal slash_stub.callCount, 0, "/ not called again"
	slash_stub.reset()

	Finch.call ""
	equal slash_stub.callCount, 0, "/ not called again"
	slash_stub.reset()

	Finch.call "//"
	equal slash_stub.callCount, 0, "/ not called again"
	slash_stub.reset()

	Finch.call "foo"
	equal slash_stub.callCount, 0, "/ not called again"
	equal foo_stub.callCount, 1, "foo called once"
	slash_stub.reset()
	foo_stub.reset()

	Finch.call "/foo"
	equal slash_stub.callCount, 0, "/ not called again"
	equal foo_stub.callCount, 0, "foo not called again"
	slash_stub.reset()
	foo_stub.reset()

	Finch.call "/foo/"
	equal slash_stub.callCount, 0, "/ not called again"
	equal foo_stub.callCount, 0, "foo not called again"
	slash_stub.reset()
	foo_stub.reset()

	Finch.call "foo/"
	equal slash_stub.callCount, 0, "/ not called again"
	equal foo_stub.callCount, 0, "foo not called again"
	slash_stub.reset()
	foo_stub.reset()

	Finch.call "foo/bar"
	equal slash_stub.callCount, 0,  	"/ not called again"
	equal foo_stub.callCount, 0,    	"foo not called again"
	equal foo_bar_stub.callCount, 1,	"foo/bar called once"
	slash_stub.reset()
	foo_stub.reset()
	foo_bar_stub.reset()

	Finch.call "/foo/bar"
	equal slash_stub.callCount, 0,  	"/ not called again"
	equal foo_stub.callCount, 0,    	"foo not called again"
	equal foo_bar_stub.callCount, 0,	"foo/bar not called again"
	slash_stub.reset()
	foo_stub.reset()
	foo_bar_stub.reset()

	Finch.call "/foo/bar/"
	equal slash_stub.callCount, 0,  	"/ not called again"
	equal foo_stub.callCount, 0,    	"foo not called again"
	equal foo_bar_stub.callCount, 0,	"foo/bar not called again"
	slash_stub.reset()
	foo_stub.reset()
	foo_bar_stub.reset()

	Finch.call "foo/bar/"
	equal slash_stub.callCount, 0,  	"/ not called again"
	equal foo_stub.callCount, 0,    	"foo not called again"
	equal foo_bar_stub.callCount, 0,	"foo/bar not called again"
	slash_stub.reset()
	foo_stub.reset()
	foo_bar_stub.reset

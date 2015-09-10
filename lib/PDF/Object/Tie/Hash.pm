use v6;

use PDF::Object::Tie;

role PDF::Object::Tie::Hash does PDF::Object::Tie {

    has Hash $.entries is rw;

    sub tie-att-hash(Hash $object, Str $key, Attribute $att) is rw {

	#| untyped attribute
	multi sub type-check($val, Mu $type) is rw {
	    if !$val.defined {
		die "missing required field: $key"
		    if $att.is-required;
		return Nil
	    }
	    $val
	}
	#| type attribute
	multi sub type-check($val is rw, $type) is rw is default {
	    if !$val.defined {
	      die "{$object.WHAT.^name}: missing required field: $key"
		  if $att.is-required;
	      return Nil
	  }
	  die "{$object.WHAT.^name}.$key: {$val.perl} - not of type: {$type.gist}"
	      unless $val ~~ $type
	      || $val ~~ Pair;	#| undereferenced - don't know it's type yet
	  $val;
	}

	#| resolve a heritable property by dereferencing /Parent entries
	proto sub inehrit(Hash $, Str $, Int :$hops) {*}
        multi sub inherit(Hash $object, Str $key where { $object{$key}:exists }, :$hops) {
	    $object{$key};
	}
	multi sub inherit(Hash $object, Str $key where { $object<Parent>:exists }, Int :$hops is copy = 1) {
	    die "cyclical inheritance hierarchy"
		if ++$hops > 100;
	    inherit($object<Parent>, $key, :$hops);
	}
	multi sub inherit(Mu $, Str $, :$hops) is default { Nil }

	Proxy.new( 
	    FETCH => method {
		my $val := $object{$key};
		$val := inherit($object, $key)
		    if !$val.defined && $att.is-inherited;
		$object.apply-att($val, $att);
		type-check($val, $att.type);
	    },
	    STORE => method ($val is copy) {
		my $lval = $object.lvalue($val);
		$object.apply-att($lval, $att);
		$att.set_value($object, $object{$key} := type-check($lval, $att.type));
	    });
    }

    method rw-accessor(Str $key!, $att) {
	tie-att-hash(self, $key, $att);
    }

    method compose($class) {
	my $class-name = $class.^name;
	my %entries;

	for $class.^attributes.grep({.name !~~ /descriptor/ && .can('entry') }) -> $att {
	    my $key = $att.accessor-name;
	    %entries{$key} = $att;

	    my &meth = method { self.rw-accessor( $key, $att ) };

	    if $att.gen-accessor &&  ! $class.^declares_method($key) {
		$att.set_rw;
		$class.^add_method( $key, &meth );
	    }

	    $class.^add_method( $_ , &meth )
		unless $class.^declares_method($_)
		for $att.aliases;
	}
	%entries;
    }

    method tie-init {
	self.entries //= PDF::Object::Tie::Hash.compose(self.WHAT);
    }

    #| for hash lookups, typically $foo<bar>
    method AT-KEY($key) is rw {
        my $val := callsame;

        $val ~~ Pair | Array | Hash
            ?? $.deref(:$key, $val)
            !! $val;
    }

    #| handle hash assignments: $foo<bar> = 42; $foo{$baz} := $x;
    method ASSIGN-KEY($key, $val) {
	nextwith($key, $.lvalue($val) )
    }
    
}

use v6;

our $loader;
our %required;

#| Perl 6 bindings to the Carousel Object System (http://jimpravetz.com/blog/2012/12/in-defense-of-cos/)
role PDF::COS {
    has $.reader is rw;
    has Int $.obj-num is rw;
    has UInt $.gen-num is rw;

    method is-indirect is rw returns Bool {
	Proxy.new(
	    FETCH => { ? self.obj-num },
	    STORE => -> \p, Bool \indirect {
		if indirect {
		    # Ensure this object is indirect. Serializer will renumber
		    self.obj-num //= -1;
		}
		else {
		    self.obj-num = Nil;
		}
	    },
	    );
    }

    multi method COERCE($v is raw) {
        self.coerce($v, self.WHAT);
    }
    proto method coerce(|) {*}
    proto method coerce-to($,$) {*}
    multi method coerce($a is raw, $b is raw) { self.coerce-to($a, $b) }
    multi method coerce-to(Mu $obj is rw, Mu $type ) {
	self!coercer.coerce-to( $obj, $type )
    }
    multi method coerce-to(Mu $obj, Mu $type ) {
	self!coercer.coerce( $obj, $type )
    }

    multi method coerce(PDF::COS $val!) { $val }

    my subset AST-Node of Associative:D where {
	use PDF::Grammar:ver(v0.1.6+) :AST-Types;
        my constant %AstTypes = AST-Types.enums;
        # e.g. { :int(42) }
        .elems == 1 && (%AstTypes{.keys[0]}:exists)
    }
    multi method coerce(%dict!, |c) {
	%dict ~~ AST-Node
	    ?? $.coerce( |%dict, |c )
	    !! $.coerce( :%dict, |c );
    }
    multi method coerce(@array!, |c) {
        $.coerce( :@array, |c )
    }
    multi method coerce(DateTime $dt, |c) {
	 $.required('PDF::COS::DateString').COERCE($dt);
    }

    method required(Str \mod-name) {
	%required{mod-name}:exists
            ?? %required{mod-name}
            !! %required{mod-name} = do given ::(mod-name) {
                $_ ~~ Failure ?? do {.so; (require ::(mod-name))} !! $_;
            }
    }
    method !add-role($obj is rw, Str $role-name, Str $param?) {
	my $role = $.required($role-name);
        $role = $role.^parameterize($_) with $param;

	$obj.does($role)
            ?? $obj
            !! $obj = $obj but $role
    }

    method load-array(List $array) {
        my $base-class = $.required('PDF::COS::Array');
        $.load-delegate( :$array, :$base-class );
    }

    method load-dict(Hash $dict, :$base-class = $.required('PDF::COS::Dict')) {
	$.load-delegate( :$dict, :$base-class );
    }

    multi method coerce( List :$array!, |c ) {
        $.load-array($array).new: :$array, |c;
    }

    my subset IndRef of Pair is export(:IndRef) where {.key eq 'ind-ref'};

    multi method coerce( List :$ind-ref! --> IndRef) {
	:$ind-ref
    }

    multi method coerce( Int :$int! is rw) {
        self!add-role($int, 'PDF::COS::Int');
    }
    multi method coerce( Int :$int! is copy) { self.coerce: :$int }

    multi method coerce( Numeric :$real! is rw) {
        self!add-role($real, 'PDF::COS::Real');
    }
    multi method coerce( Numeric :$real! is copy) { self.coerce: :$real }

    multi method coerce( Str :$hex-string! is rw) {
        self!add-role($hex-string, 'PDF::COS::ByteString', 'hex-string');
    }
    multi method coerce( Str :$hex-string! is copy) { self.coerce: :$hex-string }

    multi method coerce( Str :$literal! is rw) {
        self!add-role($literal, 'PDF::COS::ByteString');
    }
    multi method coerce( Str :$literal! is copy) { self.coerce: :$literal }

    multi method coerce( Str :$name! is rw) {
        self!add-role($name, 'PDF::COS::Name');
    }
    multi method coerce( Str :$name! is copy) { self.coerce: :$name }

    multi method coerce( Bool :$bool! is rw) {
        self!add-role($bool, 'PDF::COS::Bool');
    }
    multi method coerce( Bool :$bool! is copy) { self.coerce: :$bool }

    multi method coerce( Hash :$dict!, |c ) {
	$.load-dict($dict).new: :$dict, |c;
    }

    multi method coerce( Hash :$stream!, |c ) {
        my Hash $dict = $stream<dict> // {};
        my $base-class := $.required('PDF::COS::Stream');
	my $class = $.load-dict($dict, :$base-class);
        $class.new: |$stream, |c;
    }

    multi method coerce(:$null!) {
        $.required('PDF::COS::Null').new;
    }

    multi method coerce($val) is default { $val }

    method !coercer {
        $.required('PDF::COS::Coercer');
    }

    method loader is rw {
	unless $loader.can('load-delegate') {
	    $loader = $.required('PDF::COS::Loader');
	}
	$loader
    }

    method load-delegate(|c) {
	$.loader.load-delegate(|c);
    }

    multi method ACCEPTS(Any:D $v) is default {
        self.defined ?? $v eqv self !! callsame();
    }
}

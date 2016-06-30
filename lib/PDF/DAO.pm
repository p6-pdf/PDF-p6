use v6;

our $delegator;
our %required;

role PDF::DAO {

    has $.reader is rw;
    has Int $.obj-num is rw;
    has UInt $.gen-num is rw;

    method is-indirect is rw returns Bool {
	Proxy.new(
	    FETCH => sub ($) { ? self.obj-num },
	    STORE => sub ($, Bool $val) {
		if $val {
		    # Ensure this object is indirect. Serializer will renumber
		    self.obj-num //= -1;
		}
		else {
		    self.obj-num = Nil;
		}
		$val
	    },
	    );
    }

    multi method coerce(Mu $obj is rw, Mu $type ) {
	$.delegator.coerce( $obj, $type )
    }

    # coerce Hash & Array assignments to objects
    multi method coerce(PDF::DAO $val!) { $val }
    #| to allow round-tripping from JSON

    multi method coerce(Hash $dict!, |c) {
	use PDF::Grammar :AST-Types;
	+$dict == 1 && $dict.keys[0] ∈ AST-Types
	    ?? $.coerce( |$dict, |c )    #| JSON munged pair
	    !! $.coerce( :$dict, |c );
    }
    multi method coerce(Array $array!, |c) {
        $.coerce( :$array, |c )
    }
    multi method coerce(DateTime $dt, |c) {
	$.delegator.coerce( $dt, DateTime, |c)
    }
    multi method coerce(Pair %_!, |c) {
	$.coerce( |%_, |c)
    }
    method required(*@path where +@path) {
	my Str $mod-name = @path.join('::');
	unless %required{$mod-name}++ {
	    require ::($mod-name)
	}
    }
    method add-role($obj, Str $role) {
	$.required($role);
        $obj does ::($role)
	    unless $obj.does(::($role));
	$obj;
    }

    multi method coerce( Array :$array!, |c ) {
        $.required("PDF::DAO::Array");
        my $fallback = ::("PDF::DAO::Array");
        $.delegate( :$array, :$fallback ).new( :$array, |c );
    }

    multi method coerce( Bool :$bool!) {
	use nqp;
        $.add-role($bool, "PDF::DAO::Bool");
	$.add-role($bool, 'PDF::DAO')
	    if nqp::isrwcont($bool);
	$bool;
    }

    multi method coerce( Array :$ind-ref!) {
	:$ind-ref
    }

    multi method coerce( Int :$int!) {
        $.add-role($int, "PDF::DAO::Int");
    }

    multi method coerce( Numeric :$real!) {
        $.add-role($real, "PDF::DAO::Real");
    }

    multi method coerce( Str :$hex-string!) {
        $.add-role($hex-string, "PDF::DAO::ByteString");
        $hex-string.type = 'hex-string';
        $hex-string;
    }

    multi method coerce( Str :$literal!) {
        $.add-role( $literal, "PDF::DAO::ByteString");
        $literal.type = 'literal';
        $literal;
    }

    multi method coerce( Str :$name!) {
        $.add-role($name, "PDF::DAO::Name");
    }

    multi method coerce( Any :$null!, |c) {
        $.required("PDF::DAO::Null");
        ::("PDF::DAO::Null").new( |c );
    }

    multi method coerce( Hash :$dict!, |c ) {
        $.required("PDF::DAO::Dict");
	my $fallback = ::("PDF::DAO::Dict");
	my $class = $.delegate( :$dict, :$fallback );
	$class.new( :$dict, |c );
    }

    multi method coerce( Hash :$stream!, |c ) {
        my %params;
        for <start end encoded decoded> -> $k {
            %params{$k} = $_
                with $stream{$k};
        }
        my Hash $dict = $stream<dict> // {};
        $.required("PDF::DAO::Stream");
	my $fallback = ::("PDF::DAO::Stream");
	my $class = $.delegate( :$dict, :$fallback );
        $class.new( :$dict, |%params, |c );
    }

    multi method coerce($val) is default { $val }

    method delegator is rw {
	unless $delegator.can('delegate') {
	    $.required('PDF::DAO::Delegator');
	    $delegator = ::('PDF::DAO::Delegator');
	}
	$delegator
    }
    method delegate(|c) {
	$.delegator.delegate(|c);
    }

}

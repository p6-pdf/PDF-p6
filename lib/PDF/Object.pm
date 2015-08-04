use v6;

class PDF::Object {

    multi method compose( Array :$array!, *%etc) {
        require ::("PDF::Object::Array");
        my $fallback = ::("PDF::Object::Array");
        $.delegate( :$array, :$fallback ).new( :$array, |%etc );
    }

    multi method compose( Bool :$bool!) {
        require ::("PDF::Object::Bool");
        $bool but ::("PDF::Object::Bool");
    }

    multi method compose( Int :$int!) {
        require ::("PDF::Object::Int");
        $int but ::("PDF::Object::Int");
    }

    multi method compose( Numeric :$real!) {
        require ::("PDF::Object::Real");
        $real but ::("PDF::Object::Real");
    }

    multi method compose( Str :$hex-string!) {
        require ::("PDF::Object::ByteString");

        my Str $str = $hex-string but ::("PDF::Object::ByteString");
        $str.type = 'hex-string';
        $str;
    }

    multi method compose( Str :$literal!) {
        require ::("PDF::Object::ByteString");

        my Str $str = $literal but ::("PDF::Object::ByteString");
        $str.type = 'literal';
        $str;
    }

    multi method compose( Str :$name!) {
        require ::("PDF::Object::Name");
        $name but ::("PDF::Object::Name");
    }

    multi method compose( Any :$null!) {
        require ::("PDF::Object::Null");
        ::("PDF::Object::Null").new;
    }

    multi method compose( Hash :$dict!, *%etc) {
        require ::("PDF::Object::Dict");
	my $class = ::("PDF::Object::Dict");
	$class = $.delegate( :$dict, :fallback($class) );
	$class.new( :$dict, |%etc );
    }

    multi method compose( Hash :$stream!, *%etc) {
        my %params = %etc;
        for <start end encoded decoded> {
            %params{$_} = $stream{$_}
            if $stream{$_}:exists;
        }
        my Hash $dict = $stream<dict> // {};
        require ::("PDF::Object::Stream");
	my $class = ::("PDF::Object::Stream");
	$class = $.delegate( :$dict, :fallback($class) );
        $class.new( :$dict, |%params );
    }

    proto method is-indirect-type(|c --> Bool) {*}

    multi method is-indirect-type(Hash $dict!) {
	? <Type FunctionType PatternType ShadingType>.first({$dict{$_}:exists});
    }

    #| tba
    multi method is-indirect-type(Array $array) {
	Mu
    }

    multi method is-indirect-type($) {
	False
    }				    

    #| Extension point for PDF::DOM etc
    our $delegator;
    method delegator is rw { $delegator }
    method delegate(*%opt) {
	unless $delegator.can('delegate') {
	    require ::('PDF::Object::Delegator');
	    $delegator = ::('PDF::Object::Delegator');
	}
	$delegator.delegate(|%opt);
    }

    # coerce Hash & Array assignments to objects
    multi method coerce(PDF::Object $val!) { $val }
    multi method coerce(Hash $dict!, :$reader) {
        PDF::Object.compose( :$dict, :$reader )
    }
    multi method coerce(Array $array!, :$reader) {
        PDF::Object.compose( :$array, :$reader )
    }
    multi method coerce(*%opts) {
	PDF::Object.compose( |%opts);
    }
    multi method coerce($val) is default { $val }

    #| unique identifier for this object instance
    method id { ~ self.WHICH }

}

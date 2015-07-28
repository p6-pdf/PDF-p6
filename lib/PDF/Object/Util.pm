use v6;

module PDF::Object::Util {

    use PDF::Object;

    proto sub to-ast(|) is export(:to-ast) {*};
    multi sub to-ast(Pair $p!) {$p}
    multi sub to-ast(PDF::Object $object!) {$object.content}
    multi sub to-ast($other!) is default {
        to-ast-native $other
    }
    proto sub to-ast-native(|) is export(:to-ast-native) {*};
    multi sub to-ast-native(Int $int!) {:$int}
    multi sub to-ast-native(Numeric $real!) {:$real}
    multi sub to-ast-native(Hash $_dict!) {
        my %dict = %( $_dict.pairs.map( -> $kv { $kv.key => to-ast($kv.value) } ) );
        :%dict;
    }
    multi sub to-ast-native(Array $_array!) {
        my @array = $_array.map({ to-ast( $_ ) });
        :@array;
    }
    multi sub to-ast-native(Str $literal!) {:$literal}
    multi sub to-ast-native(Bool $bool!) {:$bool}
    multi sub to-ast-native($other) is default {
        return (:null(Any))
            unless $other.defined;
        die "don't know how to to-ast: {$other.perl}";
    }

    proto sub from-ast(|) is export(:from-ast) {*};

    multi sub from-ast( Pair $p! ) {
        from-ast( |%( $p.kv ) );
    }

    #| for JSON deserialization, e.g. { :int(42) } => :int(42)
    multi sub from-ast( Hash $h! where { .keys == 1 && .keys[0] ~~ /^<[a..z]>/} ) {
        from-ast( |%$h )
    }

    multi sub from-ast( Array :$array! ) {
        $array
    }

    multi sub from-ast( Bool :$bool! ) {
        $bool;
    }

    multi sub from-ast( Hash :$dict!, :$keys ) {
        $dict;
    }

    multi sub from-ast( Str :$encoded! ) { $encoded }

    multi sub from-ast( Str :$hex-string! ) { PDF::Object.compose( :$hex-string ) }

    multi sub from-ast( Array :$ind-ref! ) {
        :$ind-ref;
    }

    multi sub from-ast( Array :$ind-obj! ) {
        my %content = $ind-obj[2].kv;
        from-ast( |%content )
    }

    multi sub from-ast( Numeric :$int! ) {
        PDF::Object.compose :$int;
    }

    multi sub from-ast( Str :$literal! ) { $literal }

    multi sub from-ast( Str :$name! ) {
        PDF::Object.compose :$name;
    }

    multi sub from-ast( Numeric :$real! ) {
        PDF::Object.compose :$real;
    }

    multi sub from-ast( Hash :$stream! ) {
        $stream;
    }

    multi sub from-ast( $other! where !.isa(Pair) ) {
        return $other
    }

    multi sub from-ast( *@args, *%opt ) is default {
        return Any if %opt<null>:exists;

        die "unexpected from-ast arguments: {[@args].perl}"
            if @args;
        
        die "unable to from-ast {%opt.keys} struct: {%opt.perl}"
    }

}
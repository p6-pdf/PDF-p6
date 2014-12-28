use v6;

use PDF::Basic::Filter;
use PDF::Basic::Writer;
use PDF::Basic::Unbox;

class PDF::Basic
    is PDF::Basic::Filter
    is PDF::Basic::Writer
    is PDF::Basic::Unbox {

    has Str $.input;  # raw PDF image (latin-1 encoding)
    has Hash %.ind-obj-idx;
    has $.root-obj is rw;

    submethod BUILD(Hash :$ast, Str :$!input) {

        if $ast.defined {
            for $ast<body>.list  {
                #= build object index
                for .<objects>.list {
                    next unless my $ind-obj = .<ind-obj>;
                    my $obj-num = $ind-obj[0].Int;
                    my $gen-num = $ind-obj[1].Int;
                    %!ind-obj-idx{$obj-num}{$gen-num} = $ind-obj;

                    for $ind-obj[2..*] {
                        my ($type, $val) = .kv;
                        my $dict = do given $type { when 'stream' {$val<dict>} };
                        if $dict.defined && $dict<Type>.defined {
                            given $dict<Type><name> {
                                when 'XRef' {
                                    warn "obj $obj-num $gen-num: TBA cross reference streams (/Type /$_)";
                                    # locate document root
                                    $!root-obj //= $dict<Root>;
                                }
                                when 'ObjStm' {
                                    # these contain nested objects
                                    warn "obj $obj-num $gen-num: TBA object streams (/Type /$_)";
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}
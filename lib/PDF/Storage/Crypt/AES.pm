use v6;

use PDF::Storage::Crypt :Padding, :format-pass;
use PDF::Storage::Crypt::AST;

class PDF::Storage::Crypt::AES
    is PDF::Storage::Crypt
    does PDF::Storage::Crypt::AST {

    use PDF::Storage::Blob;
    use PDF::Storage::Util :resample;

    method !object-key(UInt $obj-num, UInt $gen-num ) {
	die "encyption has not been authenticated"
	    unless $.key;

	my uint8 @obj-bytes = resample([ $obj-num ], 32, 8).reverse;
	my uint8 @gen-bytes = resample([ $gen-num ], 32, 8).reverse;
	my uint8 @obj-key = flat $.key.list, @obj-bytes[0 .. 2], @gen-bytes[0 .. 1], 0x73, 0x41, 0x6C, 0x54; # 'sAIT'

	my UInt $size = +@obj-key;
	$.md5( @obj-key );
	my $key = $.md5( @obj-key );
	$size < 16 ?? $key[0 ..^ $size] !! $key;
    }

    multi method crypt( Str $text, |c) {
	$.crypt( $text.encode("latin-1"), |c ).decode("latin-1");
    }

    multi method crypt( $bytes, Str :$mode! where 'encrypt'|'decrypt',
                        UInt :$obj-num!, UInt :$gen-num! ) is default {
	# Algorithm 3.1

        my $obj-key = self!object-key( $obj-num, $gen-num );

        self."$mode"( $obj-key, $bytes);
    }

    method encrypt( $key, $bytes --> Buf) {
        my @iv = (1..16).map: { (0..255).pick };
        my $enc = Buf.new: @iv;
        $enc.append: $.aes-crypt($key, $bytes, :@iv);
        $enc;
    }

    method decrypt( $key, $bytes) {
        my @iv = $bytes[0 ..^ 16];
        my @enc = +$bytes > 16 ?? $bytes[16 .. *] !! [];
        $.aes-crypt($key, @enc, :@iv);
    }

}
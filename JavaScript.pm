package Apache::AntiSpam::JavaScript;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use Apache::Constants qw(:common);
use Apache::File;
use Carp ();

sub handler ($$) {
    my($class, $r) = @_;

    ## all stolen from Apache::AntiSpam
    my $filtered = uc($r->dir_config('Filter')) eq 'ON';

    # makes Apache::Filter aware
    # snippets stolen from Geoffrey Young's Apache::Clean 
    $r = $r->filter_register if $filtered;

    # AntiSpam filtering is done on text/* files
    return DECLINED unless ($r->content_type =~ m,^text/, && $r->is_main);

    my($fh, $status);
    if ($filtered) {
        ($fh, $status) = $r->filter_input;
        undef $fh unless $status == OK;
    } else {
        $fh = Apache::File->new($r->filename);
    }

    return DECLINED unless $fh;

    # finds and replaces e-mail addresses
    # if-statement should be outside the sub for efficiency
    my $replacer;
    if (uc($r->dir_config('AntiSpamFormat')) eq 'SPACES') {
        $replacer = sub {
            my($email, $orig) = @_;
            $orig =~ s/\@/ at /g;
            $orig =~ s/\./ dot /g;
            $orig =~ s/\-/ bar /g;
            $orig =~ s/  */ /g;
            return $orig;
        };
    } else {
        $replacer = sub {
            my($email, $orig) = @_;
            $orig =~ s/\@/-nospam\@/;
            return $orig;
        };
    }

    $r->send_http_header;

    local $/;           # slurp
    my $input = <$fh>;
    #find_emails($input, sub { $class->antispamize(@_) });

    $input =~ s|(<[aA]\b                      # <a
                 [^<>]*\b                     # any attributes
                 [hH][rR][eE][fF]=\"?         # href=
                   [mM][aA][iI][lL][tT][oO]:  # mailto:
                   ([^\"\s<>]+)               # EMAIL
                 \"?                          # href closed
                 [^<>]*                       # any attributes
               >                              # anchor closed
                 (.+?)                        # TEXT
               </[aA]>)                       # </a>

              |$class->antispamize($1, $2, $3)|sgex;

    $r->print($input);

    return OK;
}


sub antispamize {
    my($class, $orig, $email, $text) = @_;

    #$email =~ s/@/{at}/g;
    #$text =~ s/@/{at}/g;

    my $orig = "<script language=\"JavaScript\">document.write('" .
            join("'+'", $orig =~ /(.{1,4})/g) . "');</script>";

    ## may be you want to add this
    #$orig .= "<noscript>$text ($email)</noscript>";

    return $orig;
}    

1;
__END__

=head1 NAME

Apache::AntiSpam::JavaScript - Encodes mailto: E-mail addresses with JavaScript

=head1 SYNOPSIS

  # in httpd.conf
  <Location /antispam>
  SetHandler perl-script
  PerlHandler Apache::AntiSpam::JavaScript
  </Location>

  # filter aware
  PerlModule Apache::Filter
  SetHandler perl-script
  PerlSetVar Filter On
  PerlHandler Apache::RegistryFilter Apache::AntiSpam::JavaScript Apache::Compress

=head1 DESCRIPTION

Apache::AntiSpam::JavaScript is based on Apache::AntiSpam and implements
a filter module to prevent e-mail addresses exposed as is on web pages.
This module converts the anchors containing e-mail addresses (mailto:)
to JavaScript code.

   # in html-file
   <a href="mailto:alex@zeitform.de">alex@zeitform.de</a>

   # in browser
   <script language="JavaScript">
     document.write('<a h'+'ref='+'"mai'+'lto:'+'alex'+'@zei'+'tfor'+
                    'm.de'+'">al'+'ex@z'+'eitf'+'orm.'+'de</'+'a>');
   </script>

This module is Filter aware, meaning that it can work within
Apache::Filter framework without modification.

You may want to use other Apache::AntiSpam::* modules after this one.

This work is based on the Apache::AntiSpam::* modules provided by
Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>.

=head1 AUTHOR

Alex Pleiner, E<lt>alex@zeitform.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Alex Pleiner

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Apache::AntiSpam>

=cut



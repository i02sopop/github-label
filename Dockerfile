From perl:latest

RUN cpan -i JSON Data::Dumper
COPY labels.pl /labels.pl

ENTRYPOINT ["/labels.pl"]

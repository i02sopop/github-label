From perl:latest

RUN apt-get update && apt-get install -y jq
RUN cpan -i JSON Data::Dumper

COPY labels.pl /

CMD [ "perl", "/labels.pl" ]

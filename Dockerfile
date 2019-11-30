From perl:latest

RUN apt-get update && apt-get install -y jq
RUN cpan -i JSON Data::Dumper

COPY labels.pl /usr/src/myapp

WORKDIR /usr/src/myapp

CMD [ "perl", "./labels.pl" ]

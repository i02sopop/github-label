From perl:latest

COPY label.pl /label.pl

ENTRYPOINT ["/label.pl"]

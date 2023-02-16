FROM klakegg/hugo:ci AS build

ENV HUGO_DESTINATION=/public

COPY . /src 
RUN hugo -D

FROM nginx:latest
COPY --from=build /public /usr/share/nginx/html

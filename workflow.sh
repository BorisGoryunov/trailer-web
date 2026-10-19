# 1. собрать образ
docker build -t landing-dist .

# 2. достать результат локально (для проверки в Caddy)
docker create --name landing-tmp landing-dist
docker cp landing-tmp:/dist/pricep ./site/pricep
docker rm landing-tmp

# 3. проверить
curl -I http://localhost:8080/pricep/

# 4. залить на VPS
# docker run --rm landing-dist tar -C /dist -cf - pricep \
#   | ssh user@vps "tar -C /var/www/rathome -xf -"
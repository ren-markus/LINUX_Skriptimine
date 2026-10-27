
# apache paigaldusskript
#
# kontrollime, mitu korda apache2 korral OK installed
#muutuja sisse:
APACHE2=$(dpgk-query -W -f='$(Status)' apache2 2>/dev/null | grep -c 'ok installed')
# kui APACHE2 muutuja väärtus võrdub 0-ga
if [ $APACHE2 -eq 0 ]; then
        # siis ok installed ei ole leitud
        # ja väljastame vastav teade ning
        # paigaldame teenuse
        echo "Paigaldame apache2"
        apt install apache2
        echo "Apache on paigaltatud"
# kui APACHE2 muutuja väärtus võrdub 1-ga
elif [ $APACHE2 -eq 1 ]; then
        # siis ok installed on leitud 1 kord
        # ja teenus on juba paigaltatud
        echo "apache2 on juba paigaldatud"
        service apache2 start
        service apache2 status
# lõpetame tingimuslause
fi
# skript lopp

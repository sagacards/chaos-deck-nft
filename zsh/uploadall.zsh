network=${1:-local}

for file in art/*/webp/*.webp; \
    do;
        chaos=$(echo $file | sed -E "s/art\///" | sed -E "s/\/webp\/[0-9]+.webp//");
        card=$(echo $file | sed -E "s/art\/[1-9]\/webp\///" | sed -E "s/.webp//");
        echo "$file ($chaos) ($card)";
        zsh zsh/upload.zsh $file "chaos-$chaos-card-$card.webp" "Chaos #$chaos Card #$card" "chaos-$chaos card-$card" "Art asset for card #$card with a chaos level of $chaos." "image/webp" $network
    done;
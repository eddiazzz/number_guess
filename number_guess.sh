#!/bin/bash

PSQL=(psql -X -qAt --username=freecodecamp --dbname=number_guess --set=ON_ERROR_STOP=1)

echo "Enter your username:"
IFS= read -r USERNAME || exit 0

STATS=$("${PSQL[@]}" --set=username="$USERNAME" <<'SQL'
SELECT COUNT(*), MIN(games.guesses)
FROM games
JOIN users USING (user_id)
WHERE users.username = :'username';
SQL
) || exit 1

IFS='|' read -r GAMES_PLAYED BEST_GAME <<< "$STATS"

if (( GAMES_PLAYED == 0 )); then
  printf 'Welcome, %s! It looks like this is your first time here.\n' "$USERNAME"
else
  printf 'Welcome back, %s! You have played %s games, and your best game took %s guesses.\n' \
    "$USERNAME" "$GAMES_PLAYED" "$BEST_GAME"
fi

SECRET_NUMBER=$(( RANDOM % 1000 + 1 ))
GUESS_COUNT=0

echo "Guess the secret number between 1 and 1000:"
while IFS= read -r GUESS; do
  ((GUESS_COUNT += 1))

  if [[ ! $GUESS =~ ^([+-]?)0*([0-9]+)$ ]]; then
    echo "That is not an integer, guess again:"
    continue
  fi

  SIGN=${BASH_REMATCH[1]}
  DIGITS=${BASH_REMATCH[2]}

  if [[ $SIGN == "-" ]]; then
    echo "It's higher than that, guess again:"
  elif (( ${#DIGITS} > 4 )) || (( 10#$DIGITS > SECRET_NUMBER )); then
    echo "It's lower than that, guess again:"
  elif (( 10#$DIGITS < SECRET_NUMBER )); then
    echo "It's higher than that, guess again:"
  else
    "${PSQL[@]}" --set=username="$USERNAME" --set=guesses="$GUESS_COUNT" <<'SQL' || exit 1
BEGIN;
INSERT INTO users (username)
VALUES (:'username')
ON CONFLICT (username) DO NOTHING;

INSERT INTO games (user_id, guesses)
SELECT user_id, :'guesses'::integer
FROM users
WHERE username = :'username';
COMMIT;
SQL
    printf 'You guessed it in %s tries. The secret number was %s. Nice job!\n' \
      "$GUESS_COUNT" "$SECRET_NUMBER"
    exit 0
  fi
done

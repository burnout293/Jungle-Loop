# Jungle Loop — a new password for the debug menu (scripts/lock.gd).
#
# The password never goes into the game: this tool draws a key from it (PBKDF2-HMAC-SHA256, a new random
# salt, ROUNDS rounds) and writes only the salt and the key's SHA-256 into scripts/lock.gd. Then re-export
# the game. Letters count, not case, spaces or dashes (abcd-efgh = ABCD EFGH).
#
#   python tools/debug_password.py                     asks for it twice (hidden)
#   python tools/debug_password.py --random FILE       makes one (12 letters and digits) and writes it in FILE
#   python tools/debug_password.py --simple FILE       (0.58) one easy to remember, a word and two digits (lune65)
#   python tools/debug_password.py --check             asks for one and says whether it is the current one
#
# Keep the password out of the repository (a FILE outside it).
import getpass, hashlib, os, re, secrets, sys

ROUNDS = 300000
LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'      # no 0/O nor 1/I: read and typed without mistakes
LOCK = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'scripts', 'lock.gd')

def normal(p):
    return p.strip().upper().replace(' ', '').replace('-', '')

def check_of(password, salt_hex, rounds):
    key = hashlib.pbkdf2_hmac('sha256', normal(password).encode('utf-8'), bytes.fromhex(salt_hex), rounds, 32)
    return hashlib.sha256(key).hexdigest()

def current():
    text = open(LOCK, encoding='utf-8').read()
    salt = re.search(r'const SALT := "([0-9a-f]+)"', text).group(1)
    rounds = int(re.search(r'const ROUNDS := (\d+)', text).group(1))
    check = re.search(r'const CHECK := "([0-9a-f]+)"', text).group(1)
    return text, salt, rounds, check

def write(password):
    text, _, _, _ = current()
    salt = secrets.token_hex(16)
    text = re.sub(r'const SALT := "[0-9a-f]+"', 'const SALT := "%s"' % salt, text)
    text = re.sub(r'const ROUNDS := \d+', 'const ROUNDS := %d' % ROUNDS, text)
    text = re.sub(r'const CHECK := "[0-9a-f]+"', 'const CHECK := "%s"' % check_of(password, salt, ROUNDS), text)
    with open(LOCK, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)

def main():
    args = sys.argv[1:]
    if args[:1] == ['--check']:
        _, salt, rounds, check = current()
        ok = check_of(getpass.getpass('Mot de passe : '), salt, rounds) == check
        print('C\'est le bon.' if ok else 'Ce n\'est pas celui-là.')
        return
    if args[:1] == ['--simple']:                       # 0.58: a word and two digits, easy to remember
        if len(args) < 2:
            sys.exit('Indique le fichier où l\'écrire (hors du dépôt) : --simple FICHIER')
        words = ['lune', 'soleil', 'jungle', 'singe', 'tigre', 'cobra', 'liane', 'panda', 'perle', 'mangue', 'coco',
                 'fleur', 'nuage', 'volcan', 'toucan', 'jaguar', 'banane', 'orage', 'relique', 'temple', 'pepito', 'aigle']
        password = secrets.choice(words) + str(secrets.randbelow(90) + 10)
        os.makedirs(os.path.dirname(os.path.abspath(args[1])), exist_ok=True)
        with open(args[1], 'w', encoding='utf-8') as f:
            f.write('Jungle Loop — mot de passe du menu de debug (5 touches sur le badge de niveau) :\n\n    %s\n\n'
                    'Majuscules, espaces et tirets ne comptent pas. Pour en changer : python tools/debug_password.py\n'
                    '(ou --simple FICHIER pour un autre mot et deux chiffres)\n' % password)
        write(password)
        print('Nouveau mot de passe écrit dans %s ; scripts/lock.gd mis à jour (réexporte le jeu).' % args[1])
        return
    if args[:1] == ['--random']:
        if len(args) < 2:
            sys.exit('Indique le fichier où l\'écrire (hors du dépôt) : --random FICHIER')
        raw = ''.join(secrets.choice(LETTERS) for _ in range(12))
        password = '-'.join(raw[i:i + 4] for i in range(0, 12, 4))
        os.makedirs(os.path.dirname(os.path.abspath(args[1])), exist_ok=True)
        with open(args[1], 'w', encoding='utf-8') as f:
            f.write('Jungle Loop — mot de passe du menu de debug (5 touches sur le badge de niveau) :\n\n    %s\n\n'
                    'Majuscules, espaces et tirets ne comptent pas. Pour en changer : python tools/debug_password.py\n' % password)
        write(password)
        print('Nouveau mot de passe écrit dans %s ; scripts/lock.gd mis à jour (réexporte le jeu).' % args[1])
        return
    a = getpass.getpass('Nouveau mot de passe : ')
    b = getpass.getpass('Encore une fois : ')
    if a != b or len(normal(a)) < 5:
        sys.exit('Différents, ou moins de 5 lettres : rien n\'a changé.')
    write(a)
    print('scripts/lock.gd mis à jour (réexporte le jeu).')

if __name__ == '__main__':
    main()

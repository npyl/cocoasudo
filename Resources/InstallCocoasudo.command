cd "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

cp -R cocoasudo.app /usr/local/bin
ln -s /usr/local/bin/cocoasudo.app/Contents/Resources/cocoasudo.sh /usr/local/bin/cocoasudo

chmod +x /usr/local/bin/cocoasudo

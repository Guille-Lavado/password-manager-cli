#!/usr/bin/env bash

tempPassword="hola1234"

main() {
	# Leer datos del archivo cifrado
	file="$(openssl aes-256-cbc -d -pbkdf2 -in password.enc -pass pass:$tempPassword)"

	echo "$file"

	# Generar contraseña aleatoria
	newPassword=$(< /dev/random tr -dc A-Za-z0-9 | head -c20)

	# Insertar datos en el archivo cifrado
	file="${file}\n1:google:guille:${newPassword}"
	
	# Pintar tabla
	echo -e "$file" | grep : | awk -F : '{ print $2, $3, $4 }'
	
	# Guardar
	echo -e "$file" | openssl aes-256-cbc -e -pbkdf2 -out password.enc -pass pass:$tempPassword
}

main

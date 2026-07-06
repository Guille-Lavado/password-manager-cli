#!/usr/bin/env bash

temp_password="hola1234"
PASSWORD_LEN=20

# Declarar el array asociativo con las esquinas de la tabla
declare -A corners

corners[top_left]='\xe2\x94\x8c'
corners[top_right]='\xe2\x94\x90'
corners[bottom_left]='\xe2\x94\x94'
corners[bottom_right]='\xe2\x94\x98'
corners[top_t]='\xe2\x94\xac'
corners[bottom_t]='\xe2\x94\xb4'
corners[left_t]='\xe2\x94\x9c'
corners[right_t]='\xe2\x94\xa4'
corners[cross]='\xe2\x94\xbc'
corners[horizontal]='\xe2\x94\x80'
corners[vertical]='\xe2\x94\x82'	

# Esta función devuelve la longitud más grande entre los elementos de un array
max-len() {
	local max=0
	while read -r element; do
		if (( max < ${#element} )); then
			max=${#element}
		fi
	done
	echo "$max"
}

print-line() {
	local left="", middle="", right=""
	if [[ $1 == "top" ]]; then
		left=${corners[top_left]}
		middle=${corners[top_t]}
		right=${corners[top_right]}
	elif [[ $1 == "middle" ]]; then
		left=${corners[left_t]}
		middle=${corners[cross]}
		right=${corners[right_t]}
	elif [[ $1 == "bottom" ]]; then
		left=${corners[bottom_left]}
		middle=${corners[bottom_t]}
		right=${corners[bottom_right]}
	fi
	
	printf "$left"
	printf "${corners[horizontal]}%.0s" $(seq 1 $max_len_id)
	printf "$middle"
	printf "${corners[horizontal]}%.0s" $(seq 1 $max_len_service)
	printf "$middle"
	printf "${corners[horizontal]}%.0s" $(seq 1 $max_len_user)
	printf "$middle"
	printf "${corners[horizontal]}%.0s" $(seq 1 $PASSWORD_LEN)
	printf "$right\n"
}

print-table() {
	# Leer cada una de las filas separadas por saltos de linea
	local rows=""
	while read -r row; do
		rows+="$row\n"
	done

	# Titulos de la tabla
	head_id="Id"
	head_service="Service"
	head_user="User"
	head_password="Password"

	# Encontrar el tamaño de la celda más grande por columna
	local max_len_id=$(echo -en "$head_id\n$rows" | cut -d : -f 1 | max-len)
	local max_len_service=$(echo -en "S$head_service\n$rows" | cut -d : -f 2 | max-len)
	local max_len_user=$(echo -en "$head_user\n$rows" | cut -d : -f 3 | max-len)
	
	# Cabeza
	print-line top $max_len_id $max_len_service $max_len_user
	printf "${corners[vertical]}%-*s" $max_len_id $head_id
	printf "${corners[vertical]}%-*s" $max_len_service $head_service
	printf "${corners[vertical]}%-*s" $max_len_user $head_user
	printf "${corners[vertical]}%-*s" $PASSWORD_LEN $head_password
	printf "${corners[vertical]}\n"

	# Cuerpo
	while read -r row; do
		print-line middle $max_len_id $max_len_service $max_len_user

		printf "${corners[vertical]}%-*s" $max_len_id $(echo "$row" | cut -d : -f 1)
		printf "${corners[vertical]}%-*s" $max_len_service $(echo "$row" | cut -d : -f 2)
		printf "${corners[vertical]}%-*s" $max_len_user $(echo "$row" | cut -d : -f 3)
		printf "${corners[vertical]}%s" $(echo "$row" | cut -d : -f 4)
		printf "${corners[vertical]}\n"
	done < <(echo -en "$rows")
	print-line bottom $max_len_id $max_len_service $max_len_user
}

get-data() {
	echo -n "Escribe el nombre del servicio: "
	read -r service

	# Comprobar que servicio no tenga :
	echo "$service" | grep : >/dev/null 2>&1
	if [[ $? -eq 0 ]]; then 
		echo "Error: El nombre del servicio no debe de llevar :"
		exit 1 
	fi
			
	echo -n "Escribe el nombre de tu usuario: "
	read -r user

	# Comprobar que usuario no tenga :
	echo "$user" | grep : >/dev/null 2>&1
	if [[ $? -eq 0 ]]; then 
		echo "Error: El nombre del usuario no debe de llevar :"
		exit 1 
	fi
}

# Crear archivo password si no existe
if [[ ! -f password.enc ]]; then
	echo "nid=1\n0:google:guille:123456789abcdefghijk" | openssl aes-256-cbc -e -pbkdf2 -out password.enc -pass pass:$temp_password
fi

# Leer datos del archivo cifrado
file="$(openssl aes-256-cbc -d -pbkdf2 -in password.enc -pass pass:$temp_password)"

# Si no se pasa ningun argumento se pinta la tabla
if [[ $# -eq 0 ]]; then
	echo -e "$file" | grep : | print-table
fi

while getopts "crud:h" opt; do
	case "${opt}" in
		c)
			# Obtener nombre de usuario y de servicio
			get-data

			# Obtenemos id oculto en el archivo
			new_id=$(echo -e "$file" | grep -v : | cut -d '=' -f 2)
			file=$(echo -e "$file" | sed "s/nid=./nid=$((new_id+1))/")

			# Generar contraseña aleatoria
			new_password=$(< /dev/random tr -dc A-Za-z0-9 | head -c $PASSWORD_LEN)

			# Insertar datos en el archivo cifrado
			file="$file\n$new_id:$service:$user:$new_password"

			# Guardar
			echo -e "$file" | openssl aes-256-cbc -e -pbkdf2 -out password.enc -pass pass:$temp_password

			# Pintar tabla
			echo -e "$file" | grep : | print-table 
			;;
		r) echo -e "$file" | grep : | print-table ;;
		u) ;;
		d)
			# Eliminar línea
			file=$(echo -e "$file" | sed "/${OPTARG}:/d")
			# Guardar
			echo -e "$file" | openssl aes-256-cbc -e -pbkdf2 -out password.enc -pass pass:$temp_password
			# Pintar tabla
			echo -e "$file" | grep : | print-table 
			;;
		h) echo "Opción -h activada: ${OPTARG}" ;;
		*) exit 1 ;;
	esac
done

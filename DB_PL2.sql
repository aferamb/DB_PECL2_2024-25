\pset pager off

SET client_encoding = 'UTF8';

/*
 * Buscar en la documentación oficial de PostgreSQL:
 * REGEXP_MATCHES_TO_TABLE
 * RPLACE
 * REGEXP_REPLACE
 * MAKE_INTERVAL
 * TO_CHAR
 * 
 * \COPY NOMBRE ARCHIVO FROM 'RUTA' DELIMITER 'DELIMITADOR' NULL 'NULL' CSV ENCODING 'UTF8' HEADER;
 * 
 * comprueva que no haya valores no numericos en Fecha_lanz
    SELECT *
    FROM Discos_temp
    WHERE Fecha_lanz !~ '^[0-9]+$';
*/

BEGIN;
\echo '         Creando el esquema para la BBDD de intercambio de discos'

CREATE TABLE IF NOT EXISTS Grupo(
    Nombre TEXT NOT NULL,
    Url_grupo TEXT, -- NOT NULL
    CONSTRAINT pk_grupo PRIMARY KEY (Nombre)
);

CREATE TABLE IF NOT EXISTS Disco(
    Titulo TEXT NOT NULL, 
    Ano_publicacion INT NOT NULL,
    --Generos TEXT, -- MULTIEVALUADO no se ponen los generos
    Url_portada TEXT,
    Nombre_grupo TEXT NOT NULL,
    CONSTRAINT pk_disco PRIMARY KEY (Titulo, Ano_publicacion),
    CONSTRAINT fk_disco_grupo FOREIGN KEY (Nombre_grupo) REFERENCES Grupo(Nombre) 
    ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS Generos(
    Titulo_disco TEXT,
    Ano_publicacion INT,
    Genero TEXT,
    CONSTRAINT pk_genero PRIMARY KEY (Titulo_disco, Ano_publicacion, Genero) 
);

CREATE TABLE IF NOT EXISTS Canciones(
    Titulo_cancion TEXT NOT NULL,
    Titulo_disco TEXT NOT NULL,
    Ano_publicacion INT NOT NULL,
    Duracion INTERVAL NOT NULL,
    CONSTRAINT pk_cancion PRIMARY KEY (Titulo_cancion, Titulo_disco, Ano_publicacion),
    CONSTRAINT fk_cancion_disco FOREIGN KEY (Titulo_disco, Ano_publicacion) REFERENCES Disco(Titulo, Ano_publicacion)
    ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS Ediciones(
    Titulo_disco TEXT NOT NULL,
    Ano_publicacion INT NOT NULL,
    Formato TEXT NOT NULL,
    Ano_edicion INT NOT NULL, --FORMAT('YYYY')
    Pais TEXT NOT NULL,
    CONSTRAINT pk_edicion PRIMARY KEY (Titulo_disco, Ano_publicacion, Formato, Ano_edicion, Pais),
    CONSTRAINT fk_cancion_disco FOREIGN KEY (Titulo_disco, Ano_publicacion) REFERENCES Disco(Titulo, Ano_publicacion)
);

CREATE TABLE IF NOT EXISTS Usuario(
    Nombre_user TEXT NOT NULL,
    Nombre TEXT NOT NULL,
    Email TEXT NOT NULL,
    Contrasena TEXT NOT NULL,
    CONSTRAINT pk_usuario PRIMARY KEY (Nombre_user)
);

CREATE TABLE IF NOT EXISTS Tiene(
    Nombre_user TEXT NOT NULL,
    Titulo_disco TEXT NOT NULL,
    Ano_publicacion INT NOT NULL,
    Formato TEXT NOT NULL,
    Ano_edicion INT NOT NULL,
    Pais TEXT NOT NULL,
    Estado TEXT,
    CONSTRAINT pk_tiene PRIMARY KEY (Nombre_user, Titulo_disco, Ano_publicacion, Formato, Ano_edicion, Pais),
    CONSTRAINT fk_tiene_user FOREIGN KEY (Nombre_user) REFERENCES Usuario(Nombre_user)
    ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_tiene_disco FOREIGN KEY (Titulo_disco, Ano_publicacion, Formato, Ano_edicion, Pais) REFERENCES Ediciones(Titulo_disco, Ano_publicacion, Formato, Ano_edicion, Pais)
    ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS Desea(
    Titulo_disco TEXT NOT NULL,
    Ano_publicacion INT NOT NULL,
    Nombre_user TEXT NOT NULL,
    CONSTRAINT pk_desea PRIMARY KEY (Titulo_disco, Ano_publicacion, Nombre_user),
    CONSTRAINT fk_desea_user FOREIGN KEY (Nombre_user) REFERENCES Usuario(Nombre_user)
    ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_desea_disco FOREIGN KEY (Titulo_disco, Ano_publicacion) REFERENCES Disco(Titulo, Ano_publicacion)
    ON DELETE RESTRICT ON UPDATE CASCADE
);

\echo '         Creando un esquema temporal'

CREATE TABLE IF NOT EXISTS Canciones_temp(
    Id_disco TEXT,
    Titulo TEXT,
    Duracion TEXT
);

CREATE TABLE IF NOT EXISTS Discos_temp(
    Id_disco TEXT,
    Nombre_disco TEXT,
    Fecha_lanz TEXT, -------------------> INT
    Id_grupo TEXT,
    Nombre_grupo TEXT,
    Url_grupo TEXT,
    Generos TEXT,
    Url_portada TEXT
);

CREATE TABLE IF NOT EXISTS Ediciones_temp(
    Id_disco TEXT,
    Ano_edicion TEXT,
    Pais TEXT,
    Formato TEXT
);

CREATE TABLE IF NOT EXISTS Usuario_desea_disco_temp(
    Nombre_user TEXT,
    Titulo_disco TEXT,
    Ano_lanz TEXT
);

CREATE TABLE IF NOT EXISTS Usuario_tiene_edicion_temp(
    Nombre_user TEXT,
    Titulo_disco TEXT,
    Ano_lanz TEXT,
    Ano_edicion TEXT,
    Pais TEXT,
    Formato TEXT,
    Estado TEXT
);

CREATE TABLE IF NOT EXISTS Usuarios_temp(
    Nombre_completo TEXT,
    Nombre_user TEXT,
    Email TEXT,
    Contrasena TEXT
);


SET search_path TO public;  -- este comando estaba como SET search_path =''; en el script original y era el que estaba dando problemas con las tablas 

\echo '         Cargando datos'

\COPY Canciones_temp FROM 'Datos/canciones.csv' DELIMITER ';' NULL 'NULL' CSV ENCODING 'UTF8' HEADER;
\COPY Discos_temp FROM 'Datos/discos.csv' DELIMITER ';' NULL 'NULL' CSV ENCODING 'UTF8' HEADER;
\COPY Ediciones_temp FROM 'Datos/ediciones.csv' DELIMITER ';' NULL 'NULL' CSV ENCODING 'UTF8' HEADER;
\COPY Usuario_desea_disco_temp FROM 'Datos/usuario_desea_disco.csv' DELIMITER ';' NULL 'NULL' CSV ENCODING 'UTF8' HEADER;
\COPY Usuario_tiene_edicion_temp FROM 'Datos/usuario_tiene_edicion.csv' DELIMITER ';' NULL 'NULL' CSV ENCODING 'UTF8' HEADER;
\COPY Usuarios_temp FROM 'Datos/usuarios.csv' DELIMITER ';' NULL 'NULL' CSV ENCODING 'UTF8' HEADER;

\echo '         Insertando datos en el esquema final'
\echo ''
\echo 'Insercion de datos tabla Grupo'
INSERT INTO Grupo(Nombre, Url_grupo) 
SELECT DISTINCT ON (Nombre_grupo)
    Nombre_grupo, 
    Url_grupo 
FROM Discos_temp;

\echo 'Insercion de datos tabla Disco'
INSERT INTO Disco(Titulo, Ano_publicacion, Url_portada, Nombre_grupo) 
SELECT DISTINCT ON (Nombre_disco, Fecha_lanz) 
    Nombre_disco, 
    Fecha_lanz::INT, 
    Url_portada, 
    Nombre_grupo 
FROM Discos_temp; -- count (*) select on n_discos

\echo 'Insercion de datos tabla Generos'
INSERT INTO Generos (Titulo_disco, Ano_publicacion, Genero)
SELECT DISTINCT
    Nombre_disco, 
    Fecha_lanz::INT, 
    regexp_split_to_table(regexp_replace(Generos, '\[|\]|&|/|''', '', 'g'), E',')
FROM Discos_temp;


/*
INSERT INTO Canciones(Titulo_cancion, Titulo_disco, Ano_publicacion, Duracion)
SELECT 
    Titulo, -- Titulo de la canción
    Nombre_disco, -- Nombre del disco
    Fecha_lanz::INT, 
    -- Verificar si Duracion es NULL, y si no lo es, convertirla a INTERVAL
    CASE 
        WHEN Duracion IS NOT NULL THEN
            -- Convertir Duracion (mm:ss) a INTERVAL
            make_interval(
                mins => split_part(Duracion, ':', 1)::INT, 
                secs => split_part(Duracion, ':', 2)::INT
            )
        ELSE 
            NULL -- Mantener NULL si la Duracion es NULL
    END AS Duracion
FROM Canciones_temp c
JOIN Discos_temp d ON c.Id_disco = d.Id_disco
WHERE c.Titulo != '';
*/
\echo 'Insercion de datos tabla Canciones'
INSERT INTO Canciones(Titulo_cancion, Titulo_disco, Ano_publicacion, Duracion)
SELECT DISTINCT ON (Titulo, Nombre_disco, Fecha_lanz)
    Titulo, -- Titulo de la canción
    Nombre_disco, -- Nombre del disco
    Fecha_lanz::INT, 
    make_interval( -- Convertir Duracion (mm:ss) a INTERVAL usando make_interval
        mins => split_part(Duracion, ':', 1)::INT, 
        secs => split_part(Duracion, ':', 2)::INT
    ) --si no hubiese canciones de mas 60 min  ('00:' || Duracion) ::INTERVAL
FROM Canciones_temp c 
JOIN Discos_temp d ON c.Id_disco = d.Id_disco
WHERE c.Titulo != '' AND Duracion IS NOT NULL;

\echo 'Insercion de datos tabla Ediciones'
INSERT INTO Ediciones(Titulo_disco, Ano_publicacion, Formato, Ano_edicion, Pais)
SELECT DISTINCT -- en todo porque todo es PK
    Nombre_disco, 
    Fecha_lanz::INT, 
    Formato, 
    Ano_edicion::INT, 
    Pais
FROM Ediciones_temp e JOIN Discos_temp d ON e.Id_disco = d.Id_disco;

\echo 'Insercion de datos tabla Usuario'
INSERT INTO Usuario(Nombre_user, Nombre, Email, Contrasena)
SELECT DISTINCT ON (Nombre_user)
    Nombre_user, 
    Nombre_completo, 
    Email, 
    Contrasena
FROM Usuarios_temp;

\echo 'Insercion de datos tabla Tiene'
-- No se incluyen los usuarios que no existen en la tabla de usuarios
INSERT INTO Tiene(Nombre_user, Titulo_disco, Ano_publicacion, Formato, Ano_edicion, Pais, Estado)
SELECT DISTINCT ON (ute.Nombre_user, ute.Titulo_disco, ute.Ano_lanz, ute.Formato, ute.Ano_edicion, ute.Pais)
    ute.Nombre_user, 
    Titulo_disco, 
    Ano_lanz::INT, 
    Formato, 
    Ano_edicion::INT, 
    Pais, 
    Estado
FROM Usuario_tiene_edicion_temp ute JOIN Usuarios_temp u ON ute.Nombre_user = u.Nombre_user;

\echo 'Insercion de datos tabla Desea'
-- No se incluyen los usuarios que no existen en la tabla de usuarios
INSERT INTO Desea(Titulo_disco, Ano_publicacion, Nombre_user)
SELECT DISTINCT
    Titulo_disco, 
    Ano_lanz::INT, 
    udd.Nombre_user
FROM Usuario_desea_disco_temp udd JOIN Usuarios_temp u ON udd.Nombre_user = u.Nombre_user; 

\echo ''
\echo '         Datos insertados correctamente'
\echo ''

\echo 'Consulta 1: Mostrar los discos que tengan más de 5 canciones. Construir la expresión equivalente en álgebra relacional.'
-- WTF no sabia que el copilot podia hacer algebra relacional, aunque no es tan dificil de hacer, y no se si lo hace bien xd
-- 'Álgebra relacional: π_Titulo, Ano_publicacion, Num_canciones(σ_COUNT(Titulo_cancion) > 5(Disco ⨝ Canciones))'
\echo ''
SELECT DISTINCT 
    d.Titulo, 
    d.Ano_publicacion, 
    COUNT(c.Titulo_cancion) AS Num_canciones
FROM Disco d
JOIN Canciones c ON d.Titulo = c.Titulo_disco AND d.Ano_publicacion = c.Ano_publicacion
GROUP BY d.Titulo, d.Ano_publicacion
-- No se puede usar WHERE porque estamos filtrando por una función de agregación, y WHERE se usa para filtrar antes de la agregación
-- Solo se puede evaluar COUNT(c.Titulo_cancion) después de haber agrupado con GROUP BY
HAVING COUNT(c.Titulo_cancion) > 5 -- HAVING se usa para filtrar resultados de una consulta agrupada.
ORDER BY Num_canciones DESC;

\echo ''
\echo 'Consulta 2: Mostrar los vinilos que tiene el usuario Juan García Gómez junto con el título del disco, y el país y año de edición del mismo'
\echo ''

\echo ''
\echo 'Consulta 3: Disco con mayor duración de la colección. Construir la expresión equivalente en álgebra relacional.'
\echo ''
SELECT --este disco tiene la mayor duracion de todods los discos, pero no lo tiene nadie
    d.Titulo, 
    d.Ano_publicacion, 
    SUM(c.Duracion) AS Duracion_total
FROM Disco d
JOIN Canciones c ON d.Titulo = c.Titulo_disco AND d.Ano_publicacion = c.Ano_publicacion
GROUP BY d.Titulo, d.Ano_publicacion
ORDER BY Duracion_total DESC
LIMIT 1;

-- Consulta: Mostrar el disco cuya suma de la duración de las canciones sea la mayor de entre todos los discos de la colección de un usuario, para todos los usuarios'
/*
The query joins several tables to gather the necessary data:

Usuario (u) is joined with Tiene (t) on the user's name.
Tiene is joined with Canciones (c) on the album title and publication year.
Canciones is joined with Disco (d) on the album title and publication year.

The results are grouped by the user's name, album title, and publication year. 
This grouping allows the query to calculate the total duration of songs for each album per user.

The HAVING clause filters the results to include only those albums where the total duration of songs matches
the maximum total duration for that user. This is achieved through a subquery that calculates 
the maximum total duration of songs for each user. 
The subquery groups the data by user, album title, and publication year, and then calculates the total duration
 of songs for each group. The outer query compares the total duration of each album to this maximum value.

Finally, the results are ordered by the user's name and the total duration of songs in descending order 
(ORDER BY u.Nombre_user, Duracion_total DESC). 
This ensures that the albums with the longest total duration appear first for each user.
*/

-- Que me fumado (y el copilot) , no se puede hacer algebra relacional de esto, es una consulta muy compleja
SELECT 
    u.Nombre_user, 
    d.Titulo, 
    d.Ano_publicacion, 
    SUM(c.Duracion) AS Duracion_total
FROM Usuario u
JOIN Tiene t ON u.Nombre_user = t.Nombre_user
JOIN Canciones c ON t.Titulo_disco = c.Titulo_disco AND t.Ano_publicacion = c.Ano_publicacion
JOIN Disco d ON c.Titulo_disco = d.Titulo AND c.Ano_publicacion = d.Ano_publicacion
GROUP BY u.Nombre_user, d.Titulo, d.Ano_publicacion
HAVING SUM(c.Duracion) = (
    SELECT MAX(Duracion_total)
    FROM (
        SELECT 
            u2.Nombre_user, 
            SUM(c2.Duracion) AS Duracion_total
        FROM Usuario u2
        JOIN Tiene t2 ON u2.Nombre_user = t2.Nombre_user
        JOIN Canciones c2 ON t2.Titulo_disco = c2.Titulo_disco AND t2.Ano_publicacion = c2.Ano_publicacion
        GROUP BY u2.Nombre_user, c2.Titulo_disco, c2.Ano_publicacion
    ) AS subquery
    WHERE subquery.Nombre_user = u.Nombre_user
)
ORDER BY u.Nombre_user, Duracion_total DESC;


\echo ''
\echo 'Consulta 4: De los discos que tiene en su lista de deseos el usuario Juan García Gómez, indicar el nombre de los grupos musicales que los interpretan.'
\echo ''

\echo ''
\echo 'Consulta 5: Mostrar los discos publicados entre 1970 y 1972 junto con sus ediciones ordenados por el año de publicación.'
\echo '' -- para que se vea mejor, incluir algebra relacional
SELECT 
    d.Titulo, 
    d.Ano_publicacion, 
    d.Nombre_grupo,
    e.Formato, 
    e.Ano_edicion, 
    e.Pais
FROM Disco d JOIN Ediciones e ON d.Titulo = e.Titulo_disco --AND d.Ano_publicacion = e.Ano_publicacion
WHERE d.Ano_publicacion BETWEEN 1970 AND 1972
-- Coment par doc d.Titulo ASC espara poner las ediciones juntitas por el nombre del disco
ORDER BY d.Ano_publicacion ASC, d.Titulo ASC; -- ASC es el orden por defecto, se puede omitir

\echo ''
\echo 'Consulta 6: Listar el nombre de todos los grupos que han publicado discos del género ‘Electronic’. Construir la expresión equivalente en álgebra relacional.'
\echo ''

\echo ''
\echo 'Consulta 7: Lista de discos con la duración total del mismo, editados antes del año 2000.'
\echo ''

\echo ''
\echo 'Consulta 8: Lista de ediciones de discos deseados por el usuario Lorena Sáez Pérez que tiene el usuario Juan García Gómez'
\echo ''

\echo ''
\echo 'Consulta 9: Lista todas las ediciones de los discos que tiene el usuario Gómez García en un estado NM o M. Construir la expresión equivalente en álgebra relacional.'
\echo ''

\echo ''
\echo 'Consulta 10: Listar todos los usuarios junto al número de ediciones que tiene de todos los discos junto al año de lanzamiento de su disco más antiguo, el año de lanzamiento de su disco más nuevo, y el año medio de todos sus discos de su colección'
\echo ''

\echo ''
\echo 'Consulta 11: Listar el nombre de los grupos que tienen más de 5 ediciones de sus discos en la base de datos'
\echo ''

\echo ''
\echo 'Consulta 12: Lista el usuario que más discos, contando todas sus ediciones tiene en la base de datos'
\echo ''


ROLLBACK;     -- importante! permite correr el script multiples veces...p
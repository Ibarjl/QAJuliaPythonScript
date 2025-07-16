# Dockerfile (en C:\Users\iernestov\.scripts\ENTORNO_JULIA\QA\Kestra\Docker\Dockerfile)
FROM julia:latest

WORKDIR /app

# Copia tu script al directorio de trabajo en el contenedor
# La ruta es relativa al CONTEXTO DE CONSTRUCCIÓN (QA/Kestra)
COPY Kestra/Julia/logs_de_kestra.jl .

# Instala los paquetes de Julia
# Corrección: Pkd.add -> Pkg.add
RUN julia -e 'import Pkg; Pkg.add("Logging"); Pkg.add("DataFrames")'

# El comando por defecto, aunque Kestra lo sobrescriba
# Corrección: mi_script.jl -> logs_de_kestra.jl# Dockerfile (en C:\Users\iernestov\.scripts\ENTORNO_JULIA\QA\Kestra\Docker\Dockerfile)
FROM julia:latest

WORKDIR /app

# Copia tu script al directorio de trabajo en el contenedor
# La ruta es relativa al CONTEXTO DE CONSTRUCCIÓN (QA/Kestra)
COPY Julia/logs_de_kestra.jl .

# Instala los paquetes de Julia
RUN julia -e 'import Pkg; Pkg.add("Logging"); Pkg.add("DataFrames")'

# El comando por defecto, aunque Kestra lo sobrescriba
CMD ["julia", "logs_de_kestra.jl"]
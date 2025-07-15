# Dockerfile
FROM julia:latest

WORKDIR /app

# Copia tu script al directorio de trabajo en el contenedor
COPY mi_script.jl .

RUN julia -e 'import Pkg; Pkd.add("Logging"); Pkg.add("DataFrames")'


# El comando por defecto, aunque Kestra lo sobrescriba
CMD ["julia", "mi_script.jl"]
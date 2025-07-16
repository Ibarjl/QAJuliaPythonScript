FROM julia:1.10.3

WORKDIR /app

# Copia tu script al directorio de trabajo en el contenedor
# La ruta es relativa al CONTEXTO DE CONSTRUCCIÓN (QA/Kestra)
COPY Julia/logs_de_kestra.jl .

# Instala los paquetes de Julia
RUN julia -e 'import Pkg; Pkg.add("Logging"); Pkg.add("DataFrames")'

# El comando por defecto, aunque Kestra lo sobrescriba
CMD ["julia", "logs_de_kestra.jl"]

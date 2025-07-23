FROM julia:1.10.3

WORKDIR /app


RUN julia -e 'import Pkg; Pkg.add(["DataFrames", "JSON", "DataFramesMeta", "Plots", "FreqTables", "GR"]); Pkg.precompile()'

# Justificación: El comando CMD sigue apuntando a /app/logs_de_kestra.jl,
# ya que montaremos el directorio /home/int/script_ibar.jl del host en /app del contenedor.
CMD ["julia", "/app/logs_de_kestra.jl"]

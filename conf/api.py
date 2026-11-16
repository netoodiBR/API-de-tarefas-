import os
import psycopg2
from fastapi import FastAPI, Request

app = FastAPI()


def conectar():
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        dbname="tarefas",
        user="apiuser",
        password=os.environ["DB_PASS"]
    )


@app.get("/api/saude")
def saude():
    return {"status": "ok"}


@app.get("/api/tarefas")
def listar():
    con = conectar()
    cur = con.cursor()
    cur.execute("SELECT id, titulo, feita FROM tarefas ORDER BY id")
    linhas = [
        {"id": l[0], "titulo": l[1], "feita": l[2]}
        for l in cur.fetchall()
    ]
    con.close()
    return linhas


@app.post("/api/tarefas")
async def criar(req: Request):
    dados = await req.json()
    con = conectar()
    cur = con.cursor()
    cur.execute(
        "INSERT INTO tarefas (titulo) VALUES (%s) RETURNING id",
        (dados["titulo"],)
    )
    novo_id = cur.fetchone()[0]
    con.commit()
    con.close()
    return {"id": novo_id}


@app.put("/api/tarefas/{tarefa_id}")
def concluir(tarefa_id: int):
    con = conectar()
    cur = con.cursor()
    cur.execute(
        "UPDATE tarefas SET feita = true WHERE id = %s",
        (tarefa_id,)
    )
    con.commit()
    con.close()
    return {"id": tarefa_id, "feita": True}


@app.delete("/api/tarefas/{tarefa_id}")
def apagar(tarefa_id: int):
    con = conectar()
    cur = con.cursor()
    cur.execute(
        "DELETE FROM tarefas WHERE id = %s",
        (tarefa_id,)
    )
    con.commit()
    con.close()
    return {"apagada": tarefa_id}

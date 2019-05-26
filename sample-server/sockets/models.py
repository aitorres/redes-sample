from django.db import models

class Dispositivo(models.Model):

    # Variable super genérica, en realidad lo que me importa de Dispositivo es
    # su ID en este momento. EN la app real, podría tenerse un modelo que guarde
    # el ID del websocket activo, ultima conexion, si es operador o personita, etc
    tipo = models.IntegerField(
        verbose_name="Tipo"
    )
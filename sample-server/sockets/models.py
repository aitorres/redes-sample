from django.db import models

class Dispositivo(models.Model):

    tipo = models.IntegerField(
        verbose_name="Tipo"
    )
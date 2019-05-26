# chat/consumers.py
from channels.generic.websocket import WebsocketConsumer
from sockets.models import Dispositivo
import json

class BasicConsumer(WebsocketConsumer):
    """
    Consumer de ejemplo.
    """

    def connect(self):
        """
        Método a ejecutarse inmediatamente después de la conexión
        de cualquier dispositivo.
        """

        # Se intenta buscar si se pasó un app ID a través de los headers
        app_id = None
        for header in self.scope['headers']:
            if b"appid" in header[0]:
                try:
                    app_id = int(header[1])
                except ValueError:
                    pass

        # Se guarda el registro del dispositivo según el app ID, o se crea uno
        if app_id is not None:
            dispositivo = Dispositivo.objects.get(id=app_id)
            self.scope['dispositivo'] = dispositivo
        else:
            dispositivo = Dispositivo.objects.create(
                tipo=3
            )
            self.scope['dispositivo'] = dispositivo
        self.accept()

    def disconnect(self, close_code):
        """
        Se ejecuta justo al cerrar la conexión.
        """

        self.send(
            text_data="Goodbye my friend!"
        )

    def receive(self, text_data):
        """
        Al recibir un mensaje, si es un JSON exitoso, retorna el mismo mensaje
        y un mensaje adicional, ademas del codigo de dispositivo.
        """
        try:
            text_data_json = json.loads(text_data)
            message = text_data_json['message']

            self.send(text_data=json.dumps({
                'message': message,
                'dispositivo': self.scope['dispositivo'].id
            }))
        except json.JSONDecodeError:
            self.send(text_data=json.dumps({
                'message': "El mensaje enviado no es un JSON correctamente formateado (pasalo en 'message').",
                'dispositivo': self.scope['dispositivo'].id
            }))
        except Exception as e:
            self.send(text_data=json.dumps({
                'message': "Ha ocurrido un error genérico en el servidor. El error es %s." % e,
                'dispositivo': self.scope['dispositivo'].id
            }))

       
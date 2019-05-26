/// Archivo principal de esta app de pruebas.
/// En la práctica, no debería estar todo en un solo archivo pero ajá.
/// La idea es:
///   El proceso main() ejecuta la Aplicación (App)
///   App es un MaterialApp, cuyo hijo es Homepage
///   Homepage es un StatefulWidget (conserva estado)
///   HomepageState mantiene toda la lógica de estado, de conexión con el socket
///   etc
///
/// Esta app de prueba se conecta al server de prueba, permite enviar mensajes
/// y luego recibirlos (en ambos sentidos como JSON), y aparte permite generar un ID
/// de dispositivo automáticamente y guardarlo en el local storage del dispositivo.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart'; // Para web sockets
import 'package:shared_preferences/shared_preferences.dart'; // Para local storage del dispositivo
import 'dart:convert'; // Para trabajar con JSON

// Ejecuta el app
void main() => runApp(App());

/// Componente principal de la app. No hace mucho, más allá de ponerle un
/// título a la aplicación e insertar en pantalla el widget Homepage
class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {

    final title = 'Redes Sample App';

    return MaterialApp(
      title: title,
      home: HomePage(
        title: title,
      ),
    );
  }
}

/// Componente principal de la pantalla inicial (y única). Componente que conserva
/// el estado. Esta clase en particular solo recibe el título, lo guarda y genera
/// una instancia de su estado (el estado es el que maneja la lógica del app).
class HomePage extends StatefulWidget {
  final String title;

  HomePage({Key key, @required this.title})
      : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

/// Manejador de estado del Homepage. Aquí es donde ocurre lo bueno.
class _HomePageState extends State<HomePage> {

  // Controlador para recibir y manejar el texto que introduce el usuario
  TextEditingController _controller = TextEditingController();

  // Canal para conexión con el web socket, se inicializa al cargar el componente
  IOWebSocketChannel channel;

  // Manejador de localstorage, se inicializa al cargar el componente
  SharedPreferences prefs;

  // Entero para mostrar en pantalla el ID almacenado en localstorage al abrir el app (si existe), o null
  int id;

  // Entero para mostrar en pantalla el ID recibido en cada transmisión del servidor
  // (debe coincidir con el otro si no es null)
  int idRecibido;

  // Mensaje a ser mostrado en pantalla, se actualiza con cada transmisión recibida
  String message = '';

  // Booleano para saber si se cargó la conexión al socket y mostrar todo en pantalla
  bool loaded = false;

  // Host del web socket.
  // IMPORTANTE: Esta URL no es definitiva, fue la última que usé para probar localmente
  // con un dispositivo virtual de Android Studio. LO monto en Heroku y actualizo esto.
  String webSocketHost = 'ws://10.0.2.2:8000/ws/';

  /// Constructor de este manejador de estado (de esta clase). Lo único que hace es llamar
  /// a la función onInit(), que es una función *asíncrona*. Como es asíncrona, y un constructor no
  /// puede ser asíncrono, no podríamos simplemente poner todo lo que hace la función en este
  /// constructor.
  _HomePageState() {
    onInit();
  }

  /// Función asíncrona que se ejecuta una vez, al instanciar esta clase. Se encarga de:
  ///
  /// 1. Instanciar el manejador de Local Storage (asíncrono, espera a su ejecución)
  /// 2. Cargar el ID de dispositivo, si existe, en this.id
  /// 3. Conectarse con el Web Socket, mandando el ID (this.id) si no es nulo
  /// 4. Actualizar el estado para poner this.loaded en true, esto recarga lo que se muestra en pantalla
  /// 5. Suscribirse a los mensajes recibidos del servidor, cada mensaje recibido recarga lo que se muestra en pantalla
  onInit() async {
    // Instancia el manejador de localstorage
    this.prefs = await SharedPreferences.getInstance();

    // Intenta cargar del local storage el ID de dispositivo
    this.id = prefs.getInt('appId');

    // En caso de que el ID no sea nulo, se manda en la conexión al web socket para que el servidor
    // sepa cuál dispositivo es este
    if (this.id != null) {
      this.channel = IOWebSocketChannel.connect(
        this.webSocketHost,
        headers: {
          'appid': this.id
        }
      );
    } else {
      // Como no se manda ID acá, el servidor asigna uno automáticamente y posteriormente lo mandará
      this.channel = IOWebSocketChannel.connect(this.webSocketHost);
    }

    // Cambiamos el estado del componente para recargar lo que se muestra en pantalla
    setState(() {
      this.loaded = true;
    });

    // Nos suscribimos al stream de mensajes del servidor. Cada vez que llegue un mensaje, se ejecutará
    // la función (lambda) que recibe esto como parámetro
    this.channel.stream.listen(
      // En esta función, el mensaje es recibido como el parámetro 'message'
      (message) {
        // jsonMessage es un diccionario decodificado a partir del mensaje recibido. Por decisión de diseño,
        // los mensajes que pase el servidor deben ser todos JSON, y deben tener al menos el campo 'message'
        // con un mensaje de respuesta al cliente
        dynamic jsonMessage = json.decode(message);

        // En este punto, teniendo el jsonMessage, se puede agregar la lógica para definir
        // qué hacer en la aplicación, dependiendo de qué mensaje se haya recibido. TIpo, alertar al usuario
        // de algo, cambiar lo que se muestra, etc.

        // Se actualiza el estado de la aplicacion para recargar lo que se muestra en pantalla
        setState(() {
          // Se guarda el mensaje recibido, para mostrarlo en pantalla
          this.message = jsonMessage["message"];

          // Se guarda el ID de dispositivo recibido del servidor
          prefs.setInt('appId', jsonMessage["appId"]);

          // Se actualiza el idRecibido para que se muestre como el ultimo ID recibido del servidor
          this.idRecibido = prefs.getInt('appId');
        });
      }
    );
  }

  // Esto se ejecuta cada vez que se intenta mostrar en pantalla el componente, o cada vez que se
  // recarga el estado con setState
  @override
  Widget build(BuildContext context) {

    // column es el widget central, principal, lo declaramos acá ya que
    // su valor tomará un curso u otro dependiendo de si ya está todo listo para
    // mostrarse en pantalla (depende de this.loaded), esto porque el método para inicializar
    // el websocket y eso es asíncrono (se ejecuta al mismo tiempo que otras cosas) y tenemos que esperar
    // que termine para asegurarnos de tener todas las variables necesarias cargadas en memoria
    Widget column;

    // En este caso, el método onInit aún no ha marcado que todo está listo para mostrarse, así que
    // cargamos un mensajito de que esperes. Probablemente esto no se muestre por más de 2 segundos.
    if (!this.loaded) {
      column = Column(
        crossAxisAlignment: CrossAxisAlignment.start, // estética
        children: <Widget>[
          Text(
            "Cargando app..."
          ),
        ],
      );
    } else {
      // En este caso, ya onInit marcó que todo está listo para mostrarse, así que ponemos básicamente lo más
      // importante del app.
      column = Column(
        crossAxisAlignment: CrossAxisAlignment.start, // estética
        children: <Widget>[
          Text(
            "Tu ID original, al abrir el app, fue $id" // Mostramos el ID original
          ),
          Text(
            "Tu último ID recibido (y guardado) es $idRecibido" // Mostramos el último ID recibido
          ),
          Form(
            // TextFormField es un campo de texto para agregar el mensaje, probablemente
            // para el proyecto en vez de tener esto tenemos que poner los botones de auxilio y tal
            // y que se muestre uno u otro botón de acuerdo al estado actual del app, o podemos dejar al inicio
            // este campo para registrar en los logs un mensaje de auxilio, o un punto de referencia o algo
            child: TextFormField(
              controller: _controller,
              decoration: InputDecoration(labelText: 'Envia un mensaje'),
            ),
          ),
          Padding( // estética
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Text(this.message),
          ),
        ],
      );
    }

    // Independientemente de qué curso hayamos escogido, retornamos
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title), // Barra superior, muestra el título del app
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0), // estetica
        child: column, // Este column es lo que asignamos arriba
      ),
      floatingActionButton: FloatingActionButton( // botón flotante
        onPressed: _sendMessage, // Al presionar el botón, se ejecuta este método
        tooltip: 'Enviar mensaje',
        child: Icon(Icons.send),
      ),
    );
  }

  void _sendMessage() {
    // Este método se llama cuando se presiona el botón para enviar un mensaje.

    // Verifica que el mensaje no esté vacío
    if (_controller.text.isNotEmpty) {
      // Se lanza el mensaje al web socket
      this.channel.sink.add(
        '{"message": "${_controller.text}"}' // Formato JSON: {"message": "aca lo que esté en this._controller.text"}
      );
    }
  }

  @override
  void dispose() {
    // Este método se llama cuando este componente sale de la pantalla que,
    // en nuestro caso, quiere decir que se cerró la app o pasó a segundo plano.

    // Nos desconectamos del web socket
    this.channel.sink.close();

    // Terminamos de ejecutar la rutina normal de salida del componente
    super.dispose();
  }
}

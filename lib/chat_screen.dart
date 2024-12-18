// chat_screen.dart
import 'dart:math';
import 'question_data.dart';
import 'widgets.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'package:markdown_widget/config/all.dart';
import 'dart:convert';
import 'package:markdown_widget/widget/markdown.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ChatScreen extends StatefulWidget {
  final String career;
  final QuestionData ans;

  const ChatScreen({super.key, required this.career, required this.ans});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _exportWAController = TextEditingController();
  final _exportEmailController = TextEditingController();
  var _awaitingResponse = false;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  final List<MessageBubble> _chatHistory = [];
  List<String> loadingPhrases = [
    'Working on it, one sec.',
    'I\'ll get back to you on that.',
    'Just a moment, please.',
    'Let me check on that.',
    'I\'m almost there.',
    'Hang tight.',
    'Coming right up.',
    'I\'m on it.',
    'Well.. well that\'s interesting.',
    'Be right back.',
    'Just a sec, I\'m buffering.'
  ];

  @override
  void initState() {
    super.initState();
    initMessage();
  }

  void initMessage() async {
    setState(() => _awaitingResponse = true);
    String response = await fetchResultFromBard(
        'Why was I recommended the career [${widget.career}]');
    setState(() {
      _addMessage(response, false);
      _awaitingResponse = false;
    });
  }

  void _addMessage(String response, bool isUserMessage) {
    _chatHistory
        .add(MessageBubble(content: response, isUserMessage: isUserMessage));
    final chatHistoryJson = _chatHistory.map((bubble) {
      return {"content": bubble.content, "isUserMessage": bubble.isUserMessage};
    }).toList();
    debugPrint('Chat history: $chatHistoryJson');
    try {
      _listKey.currentState!.insertItem(_chatHistory.length - 1);
    } catch (e) {
      debugPrint(e.toString());
    }
    // Scroll to the bottom of the list
    // Schedule the scroll after the frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _onSubmitted(String message) async {
    _messageController.clear();
    setState(() {
      _addMessage(message, true);
      _awaitingResponse = true;
    });
    final result = await fetchResultFromBard(message);
    setState(() {
      _addMessage(result, false);
      _awaitingResponse = false;
    });
  }

  Future<String> fetchResultFromGPT(String career) async {
    OpenAI.apiKey = await rootBundle.loadString('assets/openai.key');
    OpenAI.showLogs = true;
    OpenAI.showResponsesLogs = true;

    final prompt =
        "Hello! I'm interested in learning more about $career. Can you tell me more about the career and provide some suggestions on what I should learn first?";

    final completion = await OpenAI.instance.chat.create(
      model: 'gpt-3.5-turbo',
      messages: [
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.user,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt)
          ],
        ),
      ],
      maxTokens: 150,
      temperature: 0.7,
    );

    if (completion.choices.isNotEmpty) {
      return completion.choices.first.message.content!.first.text.toString();
    } else {
      throw Exception('Failed to load result');
    }
  }

  Future<String> fetchResultFromBard(String message) async {
    final apiKey = await rootBundle.loadString('assets/bard.key');
    final endpoint =
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?alt=sse&key=$apiKey";

    final chatHistory = _chatHistory.map((bubble) {
      return {"content": bubble.content};
    }).toList();
    if (chatHistory.isEmpty) chatHistory.add({"content": message});

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'system_instruction': {
          'parts': [
            {
              'text': '''
          You are Nero, a very friendly, discerning career recommendation bot who helps students pick the best career for them and answer in markdown.
          You are trained to reject to answer questions that are too offtopic and reply in under 40-60 words unless more are needed.
          You are chatting with a student who is interested in the career ["${widget.career}"] and so will speak only regarding it.
          The student asks you to tell them more about the career and provide some suggestions on what they should learn first.
          You respond to them with the most helpful information you can think of as well as base your answers on their previous
          questions and the answers they have provided in the following survey json:\n${widget.ans.toJson()}'''
            }
          ],
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': message}
            ],
          },
        ],
        'safetySettings': [
          {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
          {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
          {
            'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            'threshold': 'BLOCK_NONE'
          },
          {
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_NONE'
          },
        ],
        'generationConfig': {
          'candidateCount': 1,
          'temperature': 0.7,
          'topP': 0.8,
        },
      }),
    );
    debugPrint("$chatHistory");
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body.replaceFirst("data: ", ""));
      debugPrint('Response: $json');
      return json['candidates'][0]['content']['parts'][0]['text'];
    } else {
      // throw Exception('Failed to load result: ${response.body}');
      return 'Status [${response.statusCode}]\nFailed to load result: ${response.body}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final clrSchm = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Talk to Nero"),
        backgroundColor: clrSchm.primaryContainer.withOpacity(0.2),
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: clrSchm.onPrimary),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Share Chat'),
                    content: const Text(
                        'How would you like to share your conversation?'),
                    actions: [
                      TextField(
                        controller: _exportWAController,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: textFormDecoration("Share Via WhatsApp",
                                "Enter your WA Number", Icons.message_outlined,
                                context: context)
                            .copyWith(
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: () async {
                              String number = _exportWAController.text;
                              if (!number.startsWith('966'))
                                number = '966$number';
                              if (![9, 12].contains(number.length)) return;
                              Navigator.of(context).pop();
                              String chatHistory = _chatHistory
                                  .map((message) =>
                                      '${message.isUserMessage ? '*You*: ' : '*Nero*: '}${message.content}')
                                  .join('\n\n');
                              await launchUrlString(
                                  'https://wa.me/$number?text=${Uri.encodeComponent(chatHistory)}');
                            },
                          ),
                        ),
                      ),
                      const Padding(padding: EdgeInsets.only(top: 24)),
                      TextField(
                        controller: _exportEmailController,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.deny(RegExp(' '))
                        ],
                        decoration: textFormDecoration(
                                "Share Via Email",
                                "Enter your Email Address",
                                Icons.email_outlined,
                                context: context)
                            .copyWith(
                                suffixIcon: IconButton(
                                    icon: const Icon(Icons.send),
                                    onPressed: () async {
                                      String mail = _exportEmailController.text;
                                      if (!mail.contains(
                                          RegExp(r'@\w+\.\w+.*$'))) return;
                                      String chatHistory = _chatHistory
                                          .map((message) =>
                                              '${message.isUserMessage ? '*You*: ' : '*Nero*: '}${message.content}')
                                          .join('\n\n');
                                      await launchUrlString(
                                          'mailto:$mail?subject=Career Rec! Chat History&body=${Uri.encodeComponent(chatHistory)}');
                                    })),
                      ),
                      const Padding(padding: EdgeInsets.only(top: 16)),
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: _chatHistory.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Column(
                        children: [
                          Expanded(
                            //width: min(720, screenSize.width * 0.95),
                            //height: screenSize.height * 0.7,
                            child: AnimatedList(
                              key: _listKey,
                              controller: _scrollController,
                              initialItemCount: _chatHistory.length,
                              itemBuilder: (context, index, animation) {
                                return SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(1, 0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: _chatHistory[index],
                                );
                              },
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color: clrSchm.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12.0),
                                border: Border.all(
                                    color: clrSchm.secondary, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: !_awaitingResponse
                                        ? RawKeyboardListener(
                                            focusNode: FocusNode(),
                                            onKey: (RawKeyEvent event) {
                                              if (event is RawKeyDownEvent) {
                                                if (event.logicalKey ==
                                                    LogicalKeyboardKey.enter) {
                                                  if (event.isShiftPressed) {
                                                    _messageController.text =
                                                        '${_messageController.text}\n';
                                                    _messageController
                                                            .selection =
                                                        TextSelection.fromPosition(
                                                            TextPosition(
                                                                offset:
                                                                    _messageController
                                                                        .text
                                                                        .length));
                                                  } else {
                                                    _onSubmitted(
                                                        _messageController
                                                            .text);
                                                  }
                                                }
                                              }
                                            },
                                            child: TextField(
                                              minLines: 1,
                                              maxLines: 5,
                                              controller: _messageController,
                                              onSubmitted: _onSubmitted,
                                              decoration: InputDecoration(
                                                hintText:
                                                    'What would you like to know...',
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0)),
                                                prefixIcon: Icon(
                                                    Icons.question_answer,
                                                    color: clrSchm.primary),
                                              ),
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              SizedBox(
                                                  height: 24,
                                                  width: 24,
                                                  child:
                                                      SpinKitPouringHourGlassRefined(
                                                          color:
                                                              clrSchm.primary)),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(16),
                                                child: StreamBuilder<String>(
                                                  stream: Stream.periodic(
                                                      const Duration(
                                                          seconds: 3),
                                                      (i) => loadingPhrases[
                                                          Random().nextInt(
                                                              loadingPhrases
                                                                  .length)]),
                                                  builder: (context, snapshot) {
                                                    return AnimatedSwitcher(
                                                      duration: const Duration(
                                                          milliseconds: 300),
                                                      transitionBuilder:
                                                          (Widget child,
                                                              Animation<double>
                                                                  animation) {
                                                        return FadeTransition(
                                                          opacity: animation,
                                                          child: ScaleTransition(
                                                              scale: animation,
                                                              alignment: Alignment
                                                                  .centerLeft,
                                                              child: child),
                                                        );
                                                      },
                                                      child: Text(
                                                        snapshot.data ??
                                                            loadingPhrases[
                                                                Random().nextInt(
                                                                    loadingPhrases
                                                                        .length)],
                                                        key: ValueKey<
                                                            String>(snapshot
                                                                .data ??
                                                            loadingPhrases[
                                                                Random().nextInt(
                                                                    loadingPhrases
                                                                        .length)]),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              )
                                            ],
                                          ),
                                  ),
                                  IconButton(
                                    onPressed: !_awaitingResponse
                                        ? () => _onSubmitted(
                                            _messageController.text.trim())
                                        : null,
                                    icon: Icon(Icons.send,
                                        color: clrSchm.primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                [
                  SpinKitPouringHourGlassRefined(
                      color: clrSchm.primary, size: 120),
                  SpinKitDancingSquare(color: clrSchm.primary, size: 120),
                  SpinKitSpinningLines(color: clrSchm.primary, size: 120),
                  SpinKitPulsingGrid(color: clrSchm.primary, size: 120)
                ][Random().nextInt(4)],
                const SizedBox(height: 10),
                StreamBuilder<String>(
                  stream: Stream.periodic(
                      const Duration(seconds: 3),
                      (i) => loadingPhrases[
                          Random().nextInt(loadingPhrases.length)]),
                  builder: (context, snapshot) {
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SizeTransition(
                              sizeFactor: animation,
                              axis: Axis.horizontal,
                              axisAlignment: -1,
                              child: child),
                        );
                      },
                      child: Text(
                        snapshot.data ??
                            loadingPhrases[
                                Random().nextInt(loadingPhrases.length)],
                        key: ValueKey<String>(snapshot.data ??
                            loadingPhrases[
                                Random().nextInt(loadingPhrases.length)]),
                        style: const TextStyle(fontSize: 20),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String content;
  final bool isUserMessage;

  const MessageBubble({
    required this.content,
    required this.isUserMessage,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUserMessage
            ? themeData.colorScheme.secondary.withOpacity(0.4)
            : themeData.colorScheme.primary.withOpacity(0.4),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  isUserMessage ? 'You' : 'Nero',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            MarkdownWidget(
                data: content,
                shrinkWrap: true,
                config: MarkdownConfig.darkConfig),
          ],
        ),
      ),
    );
  }
}

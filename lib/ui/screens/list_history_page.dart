import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/history/history_cubit.dart';
import '../../models/chat.dart';
import 'chat_details_page.dart';

class ListHistoryPage extends StatelessWidget {
  const ListHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    context.read<HistoryCubit>().fetchHistory();
    return BlocBuilder<HistoryCubit, HistoryState>(
      builder: (BuildContext context, HistoryState state) {
        final bool isLoading = state.status == HistoryStatus.loading;
        return SafeArea(
          child: Scaffold(
            appBar: AppBar(),
            body: Column(
              children: <Widget>[
                if (!isLoading)
                  if (state.history.isEmpty)
                    const Center(child: Text("(vide)"))
                  else
                    _buildList(context, state.history),
                if (isLoading) const CircularProgressIndicator(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildList(BuildContext context, List<Chat> list) => Expanded(
        child: ListView.builder(
          itemCount: list.length,
          shrinkWrap: true,
          itemBuilder: (BuildContext context, int index) {
            final Chat history = list[index];
            return ListTile(
              onTap: () {
                context.read<HistoryCubit>().setCurrentChat(history);
                Navigator.of(context)
                    .push(
                  MaterialPageRoute<dynamic>(
                    builder: (BuildContext context) => const ChatDetailsPage(),
                  ),
                )
                    .then((_) {
                  context.read<HistoryCubit>().fetchHistory();
                });
              },
              title: Text(history.entries.first.text),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_outlined),
                onPressed: () {
                  context.read<HistoryCubit>().deleteChat(history.id);
                },
              ),
            );
          },
        ),
      );
}

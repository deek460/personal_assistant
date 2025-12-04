import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/string_constants.dart';
import 'features/home/presentation/logic/home_cubit.dart';
import 'features/chat/presentation/logic/chat_cubit.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => HomeCubit()),
        BlocProvider(create: (_) => ChatCubit()),
      ],
      child: MaterialApp.router(
        title: StringConstants.homeTitle,
        theme: AppTheme.lightTheme,
        routerConfig: AppRouter.router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

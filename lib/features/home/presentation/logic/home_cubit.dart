import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

// States
abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object> get props => [];
}

class HomeInitial extends HomeState {}

class HomeListening extends HomeState {}

class HomeProcessing extends HomeState {}

// Cubit
class HomeCubit extends Cubit<HomeState> {
  HomeCubit() : super(HomeInitial());

  void startListening() {
    emit(HomeListening());
  }

  void stopListening() {
    emit(HomeInitial());
  }

  void processVoice() {
    emit(HomeProcessing());

    // Simulate processing
    Future.delayed(const Duration(seconds: 2), () {
      emit(HomeInitial());
    });
  }
}

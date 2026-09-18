/// Status of the chat feature, shared across features via core.
enum ChatStatus {
  initial,
  loading,
  updating,
  loaded,
  typing,
  success,
  streaming,
  error,
  interrupted,
  creatingChat,
}

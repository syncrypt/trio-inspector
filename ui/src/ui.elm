module Main exposing (..)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode
    exposing
        ( Decoder
        , Value
        , andThen
        , field
        , float
        , int
        , lazy
        , list
        , map
        , map2
        , map3
        , map4
        , map5
        , nullable
        , string
        , succeed
        , value
        )
import List.FlatMap exposing (flatMap)
import Time


-- MAIN


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- MODEL


type alias Stats =
    { tasksLiving : Int
    , tasksRunnable : Int
    , secondsToNextDeadline : Maybe Float
    , runSyncSoonQueueSize : Int
    , ioStatisticsBackend : String
    }


type alias Nursery =
    { id : Int
    , name : String
    , tasks : Tasks
    }


type alias Task =
    { id : Int
    , name : String
    , nurseries : List Nursery
    }


type Tasks
    = Tasks (List Task)


type alias StackFrame =
    { name : String
    , filename : String
    , lineno : Int
    , line : String
    }


type alias Stacktrace =
    List StackFrame


type alias Model =
    { rootTask : Maybe Task
    , stats : Maybe Stats
    , selectedTaskId : Maybe Int
    , stacktrace : Maybe Stacktrace
    }


initialState =
    { rootTask = Nothing
    , stats = Nothing
    , stacktrace = Nothing
    , selectedTaskId = Nothing
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( initialState
    , Cmd.batch [ loadTasks, loadStats, loadStacktrace ]
    )



-- UPDATE


type Msg
    = Update
    | GotTasks (Result Http.Error Task)
    | GotStats (Result Http.Error Stats)
    | GotStacktrace (Result Http.Error Stacktrace)
    | SelectTaskId Int


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Update ->
            ( model, Cmd.batch [ loadTasks, loadStats, loadStacktrace ] )

        GotTasks result ->
            case result of
                Ok rootTask ->
                    ( { model | rootTask = Just rootTask }, Cmd.none )

                Err _ ->
                    ( { model | rootTask = Nothing }, Cmd.none )

        GotStats result ->
            case result of
                Ok stats ->
                    ( { model | stats = Just stats }, Cmd.none )

                Err _ ->
                    ( { model | stats = Nothing }, Cmd.none )

        GotStacktrace result ->
            case result of
                Ok stacktrace ->
                    ( { model | stacktrace = Just stacktrace }, Cmd.none )

                Err _ ->
                    ( { model | stacktrace = Nothing }, Cmd.none )

        SelectTaskId id ->
            ( { model | selectedTaskId = Just id }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Time.every (2 * 1000) (\_ -> Update)



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "container" ] [ viewMain model ]


navBar : Html Msg
navBar =
    ul [ class "nav nav-tabs bg-primary" ]
        [ li [ class "nav-item" ]
            [ a [ class "nav-link active", href "#" ] [ text "Task tree" ]
            ]
        , li [ class "nav-item" ]
            [ a [ class "nav-link", href "#" ] [ text "Log" ]
            ]
        , li [ class "nav-item" ]
            [ a [ class "nav-link", href "#" ] [ text "Settings" ]
            ]
        ]


isJust : Maybe t -> Bool
isJust t =
    case t of
        Just _ ->
            True

        Nothing ->
            False


findTaskById : Task -> Int -> Maybe Task
findTaskById task id =
    if task.id == id then
        Just task
    else
        flatMap
            (\nursery ->
                let
                    (Tasks tasks) =
                        nursery.tasks
                in
                List.map (\t -> findTaskById t id) tasks |> List.filter isJust
            )
            task.nurseries
            |> List.head
            |> Maybe.withDefault Nothing


findSelectedTask : Model -> Maybe Task
findSelectedTask model =
    case model.rootTask of
        Just task ->
            model.selectedTaskId |> Maybe.andThen (findTaskById task)

        Nothing ->
            Nothing


viewMain : Model -> Html Msg
viewMain model =
    let
        selectedTask =
            findSelectedTask model
    in
    div [ class "card" ]
        [ navBar
        , div [ class "container" ]
            [ div [ class "row" ]
                [ div [ class "tasktree col-sm-6" ]
                    [ case model.rootTask of
                        Nothing ->
                            div [] []

                        Just rootTask ->
                            viewTaskTree model.selectedTaskId rootTask
                    ]
                , div [ class "stats col-sm-6" ]
                    [ case selectedTask of
                        Nothing ->
                            div [] []

                        Just task ->
                            div [] [ h3 [] [ text task.name ] ]
                    , case model.stacktrace of
                        Nothing ->
                            div [] []

                        Just stacktrace ->
                            viewStacktrace stacktrace
                    , case model.stats of
                        Nothing ->
                            div [] []

                        Just stats ->
                            viewStats stats
                    ]
                ]
            ]
        ]


viewStats : Stats -> Html Msg
viewStats stats =
    div []
        [ table [ class "table table-sm" ]
            [ thead []
                [ tr []
                    [ th [ scope "col" ] [ text "Name" ]
                    , th [ scope "col" ] [ text "Value" ]
                    ]
                ]
            , tbody []
                [ tr []
                    [ th [ scope "row" ] [ text "Number of tasks" ]
                    , td [ scope "col" ] [ text (String.fromInt stats.tasksLiving) ]
                    ]
                , tr []
                    [ th [ scope "row" ] [ text "Number of queued tasks" ]
                    , td [ scope "col" ] [ text (String.fromInt stats.tasksRunnable) ]
                    ]
                , tr []
                    [ th [ scope "row" ] [ text "IO backend" ]
                    , td [ scope "col" ] [ text stats.ioStatisticsBackend ]
                    ]
                ]
            ]
        ]


viewStacktrace : Stacktrace -> Html Msg
viewStacktrace stacktrace =
    div [ class "list-group" ]
        (List.map
            (\frame ->
                let
                    basename =
                        String.split "/" frame.filename |> List.reverse |> List.head

                    basenameWithLineNo =
                        case basename of
                            Nothing ->
                                "-"

                            Just name ->
                                name
                                    ++ ":"
                                    ++ String.fromInt frame.lineno
                in
                div [ class "list-group-item flex-column align-items-start" ]
                    [ div [ class "d-flex w-100 justify-content-between" ]
                        [ h5 [ class "mb-1" ] [ text frame.name ]
                        , small [] [ text basenameWithLineNo ]
                        ]
                    , p [ class "mb-1" ] [ text frame.line ]
                    , small [] [ text frame.filename ]
                    ]
            )
            stacktrace
        )


viewTaskTree : Maybe Int -> Task -> Html Msg
viewTaskTree selectedTaskId task =
    case task.name of
        "trio_inspector.inspector.TrioInspector.run" ->
            div [] []

        _ ->
            let
                isSelected =
                    case selectedTaskId of
                        Nothing ->
                            False

                        Just id ->
                            task.id == id

                labelClasses =
                    if isSelected then
                        " active bg-primary"
                    else
                        ""
            in
            div
                [ class "tasktree-item task" ]
                ([ div
                    [ class ("tasktree-label" ++ labelClasses)
                    , onClick (SelectTaskId task.id)
                    ]
                    [ icon "arrow_drop_down"
                    , text task.name
                    ]
                 ]
                    ++ List.map
                        (viewNurseryTree selectedTaskId)
                        task.nurseries
                )


icon : String -> Html Msg
icon name =
    Html.i [ class "material-icons" ] [ text name ]


viewNurseryTree : Maybe Int -> Nursery -> Html Msg
viewNurseryTree selectedTaskId nursery =
    let
        (Tasks children) =
            nursery.tasks
    in
    div [ class "tasktree-item nursery" ]
        ([ div []
            [ icon "arrow_drop_down"
            , text ("Nursery: " ++ nursery.name)
            ]
         ]
            ++ List.map (viewTaskTree selectedTaskId) children
        )



-- HTTP


loadTasks : Cmd Msg
loadTasks =
    Http.get
        { url = "http://127.0.0.1:5000/tasks.json"
        , expect = Http.expectJson GotTasks taskDecoder
        }


loadStats : Cmd Msg
loadStats =
    Http.get
        { url = "http://127.0.0.1:5000/stats.json"
        , expect = Http.expectJson GotStats statsDecoder
        }


loadStacktrace : Cmd Msg
loadStacktrace =
    Http.get
        { url = "http://127.0.0.1:5000/traceback.json"
        , expect = Http.expectJson GotStacktrace stacktraceDecoder
        }


nurseryDecoder : Decoder Nursery
nurseryDecoder =
    map3 Nursery
        (field "id" int)
        (field "name" string)
        (field "tasks" tasksDecoder)


tasksDecoder : Decoder Tasks
tasksDecoder =
    map Tasks (list (lazy (\_ -> taskDecoder)))


taskDecoder : Decoder Task
taskDecoder =
    map3 Task
        (field "id" int)
        (field "name" string)
        (field "nurseries" (list (lazy (\_ -> nurseryDecoder))))


statsDecoder : Decoder Stats
statsDecoder =
    map5 Stats
        (field "tasks_living" int)
        (field "tasks_runnable" int)
        (field "seconds_to_next_deadline" (nullable float))
        (field "run_sync_soon_queue_size" int)
        (field "io_statistics_backend" string)


stackFrameDecoder : Decoder StackFrame
stackFrameDecoder =
    map4
        StackFrame
        (field "name" string)
        (field "filename" string)
        (field "lineno" int)
        (field "line" string)


stacktraceDecoder : Decoder Stacktrace
stacktraceDecoder =
    field "stacktrace" (list stackFrameDecoder)

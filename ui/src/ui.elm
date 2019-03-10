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
        , map5
        , nullable
        , string
        , succeed
        , value
        )


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


type Model
    = Failure
    | Loading
    | Success Task


init : () -> ( Model, Cmd Msg )
init _ =
    ( Loading, Cmd.batch [ loadTasks, loadStats ] )



-- UPDATE


type Msg
    = Update
    | GotTasks (Result Http.Error Task)
    | GotStats (Result Http.Error Stats)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Update ->
            ( model, Cmd.batch [ loadTasks, loadStats ] )

        GotTasks result ->
            case result of
                Ok rootTask ->
                    ( Success rootTask, Cmd.none )

                Err _ ->
                    ( Failure, Cmd.none )

        GotStats result ->
            ( model, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



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


viewMain : Model -> Html Msg
viewMain model =
    div [ class "card" ]
        [ navBar
        , case model of
            Failure ->
                div []
                    [ text "Failure"
                    , button [ onClick Update ] [ text "Try Again!" ]
                    ]

            Loading ->
                text "Loading..."

            Success rootTask ->
                div []
                    [ button [ onClick Update, style "display" "block" ]
                        [ text "Reload" ]
                    , div [ class "tasktree" ] [ viewTaskTree rootTask ]
                    ]
        ]


viewTaskTree : Task -> Html Msg
viewTaskTree task =
    div [ class "tasktree-item task" ]
        ([ div []
            [ icon "arrow_drop_down"
            , text task.name
            ]
         ]
            ++ List.map
                viewNurseryTree
                task.nurseries
        )


icon : String -> Html Msg
icon name =
    Html.i [ class "material-icons" ] [ text name ]


viewNurseryTree : Nursery -> Html Msg
viewNurseryTree nursery =
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
            ++ List.map viewTaskTree children
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

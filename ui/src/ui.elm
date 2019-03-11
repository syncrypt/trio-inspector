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


type alias Model =
    { rootTask : Maybe Task
    , stats : Maybe Stats
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { rootTask = Nothing, stats = Nothing }
    , Cmd.batch [ loadTasks, loadStats ]
    )



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
                    ( { model | rootTask = Just rootTask }, Cmd.none )

                Err _ ->
                    ( { model | rootTask = Nothing }, Cmd.none )

        GotStats result ->
            case result of
                Ok stats ->
                    ( { model | stats = Just stats }, Cmd.none )

                Err _ ->
                    ( { model | stats = Nothing }, Cmd.none )



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


viewMain : Model -> Html Msg
viewMain model =
    div [ class "card" ]
        [ navBar
        , div [ class "container" ]
            [ div [ class "row" ]
                [ div [ class "tasktree col-sm-6" ]
                    [ case model.rootTask of
                        Nothing ->
                            div [] []

                        Just rootTask ->
                            viewTaskTree rootTask
                    ]
                , div [ class "stats col-sm-6" ]
                    [ case model.stats of
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

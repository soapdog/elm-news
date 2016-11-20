port module HomePage
    exposing
        ( Model
        , init
        , Msg
        , update
        , view
        , subscriptions
        , onPageLoad
        )

import Html exposing (Html, a, text, div, h1, span)
import Html.Attributes exposing (class)
import Date exposing (Date)
import Task exposing (Task, andThen)
import ErrorManager
import News.Story exposing (Story, StoryResp, StoryError)
import News.News as News exposing (DisplayStory)
import News.Reddit as Reddit
import News.HackerNews as HackerNews
import Analytics
import Http
import Components.Spinner


type alias Model =
    { allStories : List Story
    , errorManager : ErrorManager.Model
    , news : News.Model
    }


init : Model
init =
    { errorManager = ErrorManager.init
    , allStories = []
    , news = News.init
    }


onPageLoad : Model -> ( Model, Cmd Msg )
onPageLoad model =
    init
        ! [ fetchGoogleGroupMsgs "elm-dev"
          , fetchGoogleGroupMsgs "elm-discuss"
          , fetch Reddit.tag Reddit.fetch
          , fetch HackerNews.tag HackerNews.fetch
          ]


fetch : String -> Http.Request (List Story) -> Cmd Msg
fetch tag request =
    Task.attempt
        (\result -> FetchedNews tag (Result.mapError toString result))
        (Http.toTask request)


type Msg
    = ErrorManagerMessage ErrorManager.Msg
    | AnalyticsEvent Analytics.Event
    | FetchedNews String (Result String (List Story))
    | NewsMsg News.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ErrorManagerMessage errorMsg ->
            updateErrorManager errorMsg model

        AnalyticsEvent event ->
            ( model, Analytics.registerEvent event )

        FetchedNews tag (Ok stories) ->
            ( { model | allStories = model.allStories ++ stories }
            , Cmd.none
            )

        FetchedNews tag (Err rawError) ->
            let
                error =
                    { display = "Failed to fetch content from " ++ tag
                    , raw = Debug.log "" rawError
                    }
            in
                updateErrorManager (ErrorManager.AddError error) model

        NewsMsg newsMsg ->
            let
                ( newNews, cmd ) =
                    News.update newsMsg model.news
            in
                { model | news = newNews } ! [ Cmd.map NewsMsg cmd ]


updateErrorManager : ErrorManager.Msg -> Model -> ( Model, Cmd Msg )
updateErrorManager msg model =
    let
        ( newErrorMang, fx ) =
            ErrorManager.update msg model.errorManager
    in
        ( { model | errorManager = newErrorMang }
        , Cmd.map ErrorManagerMessage fx
        )


view : Maybe Date -> Int -> Model -> Html Msg
view now screenWidth model =
    let
        news =
            if List.isEmpty model.allStories then
                Components.Spinner.view
            else
                News.view
                    model.news
                    { now = now
                    , screenWidth = screenWidth
                    }
                    (List.map toDisplayStory model.allStories)
                    |> Html.map NewsMsg
    in
        div [ class "home__body" ]
            [ news
            , ErrorManager.view model.errorManager
                |> Html.map ErrorManagerMessage
            ]


toDisplayStory : Story -> DisplayStory
toDisplayStory story =
    { from = News.Author story.author
    , title = story.title
    , date = Just (story.date)
    , url = story.url
    , tag = story.tag
    }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ fetchedGoogleGroupMsgs (\resp -> FetchedNews resp.tag (Ok resp.stories))
        , errorGoogleGroupMsgs (\resp -> FetchedNews resp.tag (Err resp.error))
        ]


port fetchGoogleGroupMsgs : String -> Cmd msg


port fetchedGoogleGroupMsgs : (StoryResp -> msg) -> Sub msg


port errorGoogleGroupMsgs : (StoryError -> msg) -> Sub msg
